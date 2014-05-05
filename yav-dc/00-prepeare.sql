/* $MD_INIT$
/* */

--@: log table:dc

DROP TABLE IF EXISTS dc;
CREATE TABLE dc (
  id integer,
  n_osm_id integer,
  p_osm_id integer,
  name varchar(255),
  status varchar(100),
  okato varchar(11),
  kladr varchar(17),
  --cof_ids varchar(100),
  --cof_name varchar(255),
  geom geometry,
  CONSTRAINT dc_pk PRIMARY KEY (id)
);

$MD_INIT$ */

--@: log dc
--@: level +

TRUNCATE dc;

INSERT INTO dc (id, n_osm_id, p_osm_id, name, status, okato, kladr, geom)
SELECT DISTINCT  s.id, s.point_osm_id, s.polygon_osm_id, okato.name, okato.status, okato.code,  s.kladr, geom_point
FROM settlement s
  INNER JOIN settlement_okato_match om ON s.id = om.obj_id
  INNER JOIN oktmo k ON k.capital = om.dict_id AND k.cls IN ('го', 'мр')
  INNER JOIN okato ON okato.id = om.dict_id;

--@: level -
