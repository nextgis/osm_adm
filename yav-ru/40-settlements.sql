/* $MD_INIT$

--@: log table: settlement
DROP TABLE IF EXISTS settlement;

CREATE TABLE settlement
(
  id integer,
  point_osm_id integer,
  polygon_osm_id integer,
  "name" character varying(200),
  place character varying(50),
  geom_point geometry,
  geom_polygon geometry,
  okato character varying(11),
  okato_status smallint,
  kladr character varying(17),
  okato_polygon integer,
  variants character varying(255),
  -- v_name character varying(100)[],
  -- v_status character varying(100)[],
  name_all text,
  parent_boundary_oktmo integer,
  parents_oktmo integer[],
  parent_boundary_oktmo_polygon_osm_id integer,
  okato_user character varying(11),
  admin_levels varchar(3)[],
  kladr_user text,
  CONSTRAINT settlement_pk PRIMARY KEY (id)
);

CREATE INDEX settlement_geom_point ON settlement USING gist (geom_point);
CREATE INDEX settlement_geom_polygon ON settlement USING gist (geom_polygon);
CREATE INDEX settlement_okato ON settlement USING btree (okato);

--@: sequence: settlement_id_seq
DROP SEQUENCE IF EXISTS settlement_id_seq;
CREATE SEQUENCE settlement_id_seq;


$MD_INIT$ */

--@: log settlement
--@: level +

--@: log temp tables

DROP TABLE IF EXISTS tmp_src_settlement_polygon, tmp_src_settlement_point;
CREATE TEMP TABLE tmp_src_settlement_polygon (
  osm_id int,
  name text,
  place text,
  okato_user text,
  admin_level text,
  official_status text,
  kladr_user text,
  geom geometry
);

CREATE TEMP TABLE tmp_src_settlement_point (
  osm_id int,
  name text,
  place text,
  okato_user text,
  admin_level text,
  official_status text,
  kladr_user text,
  geom geometry
);

--@: log query to osm_point

INSERT INTO tmp_src_settlement_point
SELECT osm_id, COALESCE(name, place_name) , place, substring("okato:user" from 1 for 11), admin_level, official_status, "kladr:user", way
FROM osm_point
WHERE (place IN ('city', 'town', 'village', 'hamlet') OR "okato:user" IS NOT NULL);

--@: log query to osm_polygon
INSERT INTO tmp_src_settlement_polygon
SELECT osm_id, COALESCE(name, place_name) , place, substring("okato:user" from 1 for 11), admin_level, official_status, "kladr:user", way
FROM osm_polygon
WHERE (place IN ('city', 'town', 'village', 'hamlet')) AND ST_IsValid(way);

--@: log building indexes
CREATE INDEX tmp_src_settlement_polygon_geom ON tmp_src_settlement_polygon USING gist (geom);
CREATE INDEX tmp_src_settlement_point_geom ON tmp_src_settlement_point USING gist (geom);
CREATE INDEX tmp_src_settlement_polygon_name ON tmp_src_settlement_polygon (name);
CREATE INDEX tmp_src_settlement_point_name ON tmp_src_settlement_point (name);
  

--@: log truncate settlement
TRUNCATE settlement;

--@: log point + polygon or point only
INSERT INTO settlement (id, point_osm_id, polygon_osm_id, name,
                        place, geom_point, geom_polygon, okato_user,
                        admin_levels, kladr_user)
SELECT 
	nextval('settlement_id_seq') AS id,
	n.osm_id AS point_osm_id,
	p.osm_id AS polygon_osm_id, 
	regexp_replace(COALESCE(n.name, p.name),'ё','е') AS name,
	n.place AS place,
	COALESCE(n.geom, ST_PointOnSurface(p.geom)) AS geom_point,
	p.geom AS geom_polygon,
	COALESCE(n.okato_user, p.okato_user),
	string_to_array(COALESCE(n.admin_level, p.admin_level), ';'),
	COALESCE(n.kladr_user, p.kladr_user)
FROM tmp_src_settlement_point n
	LEFT JOIN tmp_src_settlement_polygon p  ON 
		(n.name = p.name OR p.name IS NULL)
		AND n.geom && p.geom AND ST_Within(n.geom, p.geom)
WHERE n.place IN ('city', 'town', 'village', 'hamlet');

--@: log polygon only
INSERT INTO settlement (id, point_osm_id, polygon_osm_id, name, place, geom_point, geom_polygon, okato_user, admin_levels, kladr_user)
SELECT 
	nextval('settlement_id_seq') AS id,
	NULL AS point_osm_id,
	p.osm_id AS polygon_osm_id, 
	regexp_replace(p.name,'ё','е') AS name,
	p.place AS place,
	ST_PointOnSurface(p.geom) AS geom_point,
	p.geom AS geom_polygon,
	p.okato_user,
	string_to_array(COALESCE(n.admin_level, p.admin_level), ';'),
	COALESCE(n.kladr_user, p.kladr_user)
FROM tmp_src_settlement_point n
	RIGHT JOIN tmp_src_settlement_polygon p  ON 
		(n.name = p.name OR p.name IS NULL)
		AND n.geom && p.geom AND ST_Within(n.geom, p.geom)
WHERE n.osm_id IS NULL;

--@: log non place=* with oktmo:user
INSERT INTO settlement (id, point_osm_id, polygon_osm_id, name, place, geom_point, geom_polygon, okato_user, admin_levels)
SELECT nextval('settlement_id_seq') AS id,
  osm_id as point_osm_id, 
  NULL AS polygon_osm_id,
  regexp_replace(name,'ё','е') AS name,
  place,
  geom,
  NULL,
  CASE WHEN okato_user = 'any' THEN NULL
    ELSE okato_user END,
  string_to_array(admin_level, ';')
FROM tmp_src_settlement_point
WHERE NOT (place IN ('city', 'town', 'village', 'hamlet')) AND okato_user IS NOT NULL;


--@: log proccessing names
UPDATE settlement SET name_all = name;

UPDATE settlement SET name_all = name_all || COALESCE(';' || osm_polygon.alt_name, '')
FROM osm_polygon WHERE osm_id = polygon_osm_id;

UPDATE settlement SET name_all = name_all || COALESCE(';' || osm_point.alt_name, '')
FROM osm_point WHERE osm_id = point_osm_id;

-- UPDATE settlement SET
--   variants = name_variants_t(normalize_name(settlement."name_all"), '');

-- UPDATE settlement SET
--   v_name = regexp_split_to_array(split_part(variants, '||', 1), ';'),
--   v_status = regexp_split_to_array(split_part(variants, '||', 2), ';');

--@: level -
