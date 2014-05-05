/* $MD_INIT$

--@: log table: boundary_browser

DROP TABLE IF EXISTS boundary_browser;
CREATE TABLE boundary_browser
(
  src character varying(10) NOT NULL,
  id integer NOT NULL,
  parent_src character varying(10),
  parent_id integer,
  "name" character varying(255),
  admin_level integer,
  polygon_osm_id integer,
  oktmo_code character varying(8),
  oktmo_cls character varying(10),
  oktmo_src character(1),
  oktmo_capital bigint,
  status character varying(10),
  CONSTRAINT boundary_browser_pkey PRIMARY KEY (src, id)
);

CREATE INDEX boundary_browser_parent_idx
  ON boundary_browser
  USING btree
  (parent_src, parent_id);

CREATE INDEX boundary_browser_oktmo_capital_idx
  ON boundary_browser
  USING btree
  (oktmo_capital);

$MD_INIT$ */

--@: log boundary browser

TRUNCATE boundary_browser;

INSERT INTO boundary_browser (src, id, parent_src, parent_id, name, oktmo_code, oktmo_cls, oktmo_src, polygon_osm_id, admin_level, status)
WITH RECURSIVE oktmo_h(src, id, parent_src, parent_id, name, oktmo_code, oktmo_cls, oktmo_src, polygon_osm_id, admin_level, status) AS (
  SELECT 'oktmo'::text AS src, oktmo.id, boundary_oktmo.boundary_src AS parent_src, boundary_oktmo.boundary AS parent_id, oktmo.simple_name AS name, oktmo.code AS oktmo_code, oktmo.cls AS oktmo_cls, NULL::text AS oktmo_src, NULL::integer AS polygon_osm_id, 
    CASE
      WHEN oktmo.cls::text = 'сф'::text THEN 4
      WHEN oktmo.cls::text = ANY (ARRAY['го'::character varying, 'мр'::character varying]::text[]) THEN 6
      WHEN oktmo.cls::text = ANY (ARRAY['гп'::character varying, 'сп'::character varying, 'мс'::character varying, 'тгфз'::character varying]::text[]) THEN 8
      ELSE NULL::integer
    END AS admin_level, 'none'::text AS status
  FROM (SELECT 'polygon' AS boundary_src, boundary_oktmo.boundary, boundary_oktmo.oktmo FROM boundary_oktmo WHERE oktmo IS NOT NULL
         UNION 
        SELECT 'polygon'::text AS boundary_src, -60189 AS boundary, NULL::integer AS oktmo 
        ) boundary_oktmo
    LEFT JOIN oktmo parent_oktmo ON parent_oktmo.id = boundary_oktmo.oktmo
    LEFT JOIN oktmo ON oktmo.parent_obj::int = boundary_oktmo.oktmo::int OR (oktmo.parent_obj IS NULL AND oktmo.parent IS NULL AND boundary_oktmo.oktmo IS NULL)--parent_oktmo.code::text
    LEFT JOIN boundary_oktmo ck ON ck.oktmo = oktmo.id
  WHERE oktmo.id IS NOT NULL AND ck.oktmo IS NULL AND NOT oktmo.is_group

  UNION ALL 

  SELECT 'oktmo'::text AS src, oktmo.id, 'oktmo'::text AS parent_src, parent_oktmo.id AS parent_id, oktmo.simple_name AS name, oktmo.code AS oktmo_code, oktmo.cls AS oktmo_cls, NULL::text AS oktmo_src, NULL::integer AS polygon_osm_id, 
    CASE
      WHEN oktmo.cls::text = 'сф'::text THEN 4
      WHEN oktmo.cls::text = ANY (ARRAY['го'::character varying, 'мр'::character varying]::text[]) THEN 6
      WHEN oktmo.cls::text = ANY (ARRAY['гп'::character varying, 'сп'::character varying, 'мс'::character varying, 'тгфз'::character varying]::text[]) THEN 8
      ELSE NULL::integer
    END AS admin_level, 'none'::text AS status
  FROM oktmo_h
    LEFT JOIN oktmo parent_oktmo ON parent_oktmo.code::text = oktmo_h.oktmo_code::text
    LEFT JOIN oktmo ON oktmo.parent_obj::text = parent_oktmo.code::text
    LEFT JOIN boundary_oktmo ck ON ck.oktmo = oktmo.id
  WHERE oktmo.id IS NOT NULL AND ck.oktmo IS NULL AND NOT oktmo.is_group
)
SELECT oktmo_h.src, oktmo_h.id, 
  oktmo_h.parent_src, 
  oktmo_h.parent_id, 
  oktmo_h.name, oktmo_h.oktmo_code,
  oktmo_h.oktmo_cls, oktmo_h.oktmo_src, oktmo_h.polygon_osm_id, oktmo_h.admin_level, oktmo_h.status
FROM oktmo_h

UNION 

SELECT 'polygon'::text AS src, boundary.id, 
      CASE
          WHEN boundary.parent IS NULL THEN NULL::text
          ELSE 'polygon'::text
      END AS parent_src, 
      boundary.parent AS parent_id, 
      boundary.name, 
      oktmo.code AS oktmo_code, oktmo.cls AS oktmo_cls, boundary_oktmo.src AS oktmo_src,
      boundary.polygon_osm_id, boundary.admin_level, 
      CASE
          WHEN (boundary.admin_level = ANY (ARRAY[4, 6, 8])) AND oktmo.code IS NULL THEN 'mismatch'::text
          WHEN (boundary.admin_level = ANY (ARRAY[4, 6, 8])) AND oktmo.code IS NOT NULL THEN 'match'::text
          ELSE NULL::text
      END AS status
FROM boundary
LEFT JOIN boundary_oktmo ON boundary.id = boundary_oktmo.boundary
LEFT JOIN oktmo ON oktmo.id = boundary_oktmo.oktmo;

UPDATE boundary_browser SET
  oktmo_capital = oktmo.capital
FROM oktmo WHERE oktmo_code = oktmo.code;