/* $MD_INIT$
/* */

--@: log table: adm_boundary

DROP TABLE IF EXISTS adm_boundary;
CREATE TABLE adm_boundary (
  id integer NOT NULL,
  polygon_osm_id integer,
  osm_name character varying(255),
  admin_level integer,
  oktmo_code character varying(8),
  oktmo_name character varying(255),
  okato_code character varying(11),
  okato_name character varying(255),
  area double precision,
  osm_name_en character varying(255),
  name_lat character varying(255),
  adm3_id integer,
  adm3_name character varying(255),
  adm4_id integer,
  adm4_name character varying(255),
  geom geometry,
  geom_f geometry,
  CONSTRAINT adm_boundary_pk PRIMARY KEY (id)
);

CREATE INDEX adm_boundary_geom_idx ON adm_boundary USING GIST (geom);

--@: log function: yav_filter_polygon
CREATE OR REPLACE FUNCTION yav_filter_polygon(g geometry) RETURNS geometry AS $BODY$
  SELECT ST_Union(geom) FROM (
    SELECT geom FROM (
      SELECT ST_GeometryN(ST_Multi($1), generate_series(1, ST_NumGeometries(ST_Multi($1)))) AS geom
    ) p WHERE geometrytype(geom) IN ('POLYGON', 'MULTIPOLYGON')
  ) pf
$BODY$ LANGUAGE sql IMMUTABLE COST 1000;

$MD_INIT$ */

--@: log adm_boundary
--@: level +

TRUNCATE adm_boundary;

--@: log extract
INSERT INTO adm_boundary (id, polygon_osm_id, osm_name, admin_level, oktmo_code, geom, geom_f)
SELECT id, polygon_osm_id, name, admin_level, oktmo, geom, geom AS geom_f
FROM boundary WHERE 
  polygon_osm_id = -60189  OR 
  admin_level = 3 OR
  (admin_level IN (4,6) AND oktmo IS NOT NULL)  OR 
  (admin_level = 8 AND (oktmo LIkE '45%' OR oktmo LIKE '40%'));  

--@: log assign parent: step 1 of 2
UPDATE adm_boundary SET
  adm3_id = prnt.id,
  adm3_name = prnt.name
FROM ( SELECT is_in.child, p.id, p.name FROM boundary_is_in is_in INNER JOIN boundary p ON p.id = is_in.parent
       WHERE p.admin_level = 3 ) prnt
WHERE prnt.child = adm_boundary.id;

--@: log assign parent: step 2 of 2
UPDATE adm_boundary SET
  adm4_id = prnt.id,
  adm4_name = prnt.name
FROM ( SELECT is_in.child, p.id, p.name FROM boundary_is_in is_in INNER JOIN boundary p ON p.id = is_in.parent
       WHERE p.admin_level = 4 ) prnt
WHERE prnt.child = adm_boundary.id;


--@: log clip boundary: step 1 of 3
UPDATE adm_boundary SET
  geom = yav_filter_polygon(ST_Intersection(adm_boundary.geom, adm_clip.geom))
FROM adm_clip WHERE admin_level IN (2,3);

--@: log clip boundary: step 2 of 3
UPDATE adm_boundary SET
  geom = yav_filter_polygon(ST_Intersection(adm_boundary.geom, adm_clip.geom))
FROM adm_clip WHERE admin_level IN (4);


--@: log clip boundary: step 3 of 3
UPDATE adm_boundary c SET
  geom = yav_filter_polygon(ST_Intersection(c.geom, p.geom))
FROM adm_boundary p WHERE p.id = c.adm4_id; 

--@: log attach oktmo_name
UPDATE adm_boundary SET
  oktmo_name = raw
FROM oktmo
WHERE oktmo.code = oktmo_code;

--@: log attach okato_code
UPDATE adm_boundary SET
  okato_code = o2o.okato
FROM oktmo_to_okato o2o 
WHERE o2o.oktmo = oktmo_code;

--@: log attach okato_name
UPDATE adm_boundary SET
  okato_name = raw
FROM okato WHERE code = okato_code;

--@: log attach area 
UPDATE adm_boundary SET
  area = ST_Area(geography(geom))/(1000*1000);
  
--@: log attach name_lat
UPDATE adm_boundary SET
  name_lat = yav_translit(osm_name);

--@: level -