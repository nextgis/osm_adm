/* $MD_INIT$

--@: log table: settlement_browser_multiple

DROP TABLE IF EXISTS settlement_browser_multiple;
CREATE TABLE settlement_browser_multiple
(
  from_src character varying(10),
  from_id bigint,
  to_src character varying(10),
  to_id bigint
);

$MD_INIT$ */

--@: log settlement browser multimatch

TRUNCATE settlement_browser_multiple;

INSERT INTO settlement_browser_multiple 
WITH RECURSIVE v (start_src, start_id, var_src, var_id) AS (
  SELECT * FROM (
  SELECT DISTINCT s.src, s.id, s.src, s.id
  FROM settlement_browser s INNER JOIN settlement_okato_multiple om ON
    (s.src = 'osm' AND om.obj_id = s.id) OR (s.src = 'okato' AND om.dict_id = s.id) ) t
  
  UNION

  SELECT v.start_src, v.start_id, 
    CASE WHEN v.var_src = 'okato' THEN 'osm'::varchar(10) WHEN v.var_src = 'osm' THEN 'okato'::varchar(10) ELSE NULL::varchar(10) END,
    CASE WHEN v.var_src = 'okato' THEN om_d.obj_id WHEN v.var_src = 'osm' THEN om_o.dict_id ELSE NULL END
  FROM v 
    LEFT JOIN settlement_okato_multiple om_d ON om_d.dict_id = v.var_id AND v.var_src= 'okato'
    LEFT JOIN settlement_okato_multiple om_o ON om_o.obj_id = v.var_id AND v.var_src= 'osm'
  WHERE om_d.dict_id IS NOT NULL OR om_o.obj_id IS NOT NULL
)
SELECT * FROM v 
ORDER BY v.start_src, v.start_id;