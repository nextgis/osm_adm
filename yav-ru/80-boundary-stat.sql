/* $MD_INIT$

--@: log table: boundary_stat

DROP TABLE IF EXISTS boundary_stat;
CREATE TABLE boundary_stat
(
  src character varying(10),
  id integer,
  grp character varying(20),
  total integer,
  "match" integer,
  "none" integer,
  mismatch integer,
  "unknown" integer,
  skipped integer --,
  --CONSTRAINT boundary_stat_pk PRIMARY KEY (src, id)
);

$MD_INIT$ */

--@: log boundary stat

TRUNCATE boundary_stat;

INSERT INTO boundary_stat
WITH d_stat (src, id, grp, status, val) AS ( 
  SELECT bndr.src, bndr.id, 
    'boundary-' || child.admin_level::text || '' AS grp,
    child.status,
    COUNT(child.id)
  FROM boundary_browser bndr LEFT JOIN boundary_browser child ON child.parent_id = bndr.id
  WHERE child.admin_level IN (4,6,8)
  GROUP BY bndr.src, bndr.id, grp, child.status

  UNION 

  SELECT boundary_src, boundary_id, 
    'okato-' || grp,
    settlement_browser.status, COUNT(settlement_browser.id)
  FROM settlement_browser
    LEFT JOIN okato ON okato_code = okato.code
    LEFT JOIN settlement ON settlement_browser.src = 'osm' AND settlement.id = settlement_browser.id
  GROUP BY boundary_src, boundary_id, grp, settlement_browser.status

  

  UNION

  SELECT boundary_src, boundary_id, 
    'capital-6',
    settlement_browser.status, COUNT(settlement_browser.id)
  FROM settlement_browser
    LEFT JOIN okato ON okato_code = okato.code
    LEFT JOIN oktmo ON oktmo.capital = okato.id AND oktmo.cls IN ('го', 'мр')
  WHERE
    oktmo.id IS NOT NULL
  GROUP BY boundary_src, boundary_id, settlement_browser.status

  UNION

  SELECT boundary_src, boundary_id, 
    'capital-8',
    settlement_browser.status, COUNT(settlement_browser.id)
  FROM settlement_browser
    LEFT JOIN okato ON okato_code = okato.code
    LEFT JOIN oktmo ON oktmo.capital = okato.id AND oktmo.cls IN ('сп', 'гп')
  WHERE
    oktmo.id IS NOT NULL
  GROUP BY boundary_src, boundary_id, settlement_browser.status
 
  
),
browser_hierarchy (src, id, child_src, child_id) AS (
  WITH RECURSIVE h_stat_src (parent_src, parent_id, child_src, child_id) AS (
    SELECT src, id, src, id
    FROM boundary_browser
    WHERE parent_id IS NULL

    UNION

    SELECT
      CASE WHEN mult.v = 0 THEN top.parent_src ELSE child.src END, 
      CASE WHEN mult.v = 0 THEN top.parent_id ELSE child.id END, 
      child.src, child.id
    FROM h_stat_src top LEFT JOIN boundary_browser child ON top.child_src = child.parent_src AND top.child_id = child.parent_id
      LEFT JOIN (SELECT 0 AS v UNION SELECT 1) mult ON 1 = 1
    WHERE child.id IS NOT NULL
  ) 
  SELECT * FROM h_stat_src
)
SELECT bh.src, bh.id, grp, SUM(COALESCE(val, 0)) AS total,
  SUM(CASE WHEN status = 'match' THEN val ELSE 0 END) AS match,
  SUM(CASE WHEN status = 'none' THEN val ELSE 0 END) AS none,
  SUM(CASE WHEN status = 'mismatch' THEN val ELSE 0 END) AS mismatch,
  SUM(CASE WHEN status = 'unknown' THEN val ELSE 0 END) AS unknown,
  SUM(CASE WHEN status = 'skipped' THEN val ELSE 0 END) AS skipped
FROM browser_hierarchy bh 
  LEFT JOIN d_stat ON bh.child_id = d_stat.id AND d_stat.src = bh.child_src
WHERE grp IS NOT NULL
GROUP BY bh.src, bh.id, grp;