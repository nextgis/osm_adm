/* $MD_INIT$

--@: log table: boundary
DROP TABLE IF EXISTS boundary;

CREATE TABLE boundary
(
  id integer NOT NULL,
  polygon_osm_id integer,
  capital_point_osm_id integer,
  "name" character varying(150),
  admin_level integer,
  geom geometry,
  name_all text,
  variants text,
  v_name text[],
  v_status text[],
  oktmo character(8),
  oktmo_name character varying(150),
  parents integer[],
  parent_oktmo integer,
  parents_oktmo integer[],
  childs_oktmo integer[],
  geom_okato geometry,
  federal_subject character varying(100),
  oktmo_user character(8),
  name_en character varying(255),
  parent integer,
  CONSTRAINT boundary_id PRIMARY KEY (id),
  CONSTRAINT enforce_dims_geom CHECK (ndims(geom) = 2),
  CONSTRAINT enforce_srid_geom CHECK (srid(geom) = 4326)
);

CREATE INDEX boundary_admin_level ON boundary USING btree (admin_level);
CREATE INDEX boundary_geom ON boundary USING gist (geom);
CREATE INDEX boundary_geom_okato ON boundary USING gist (geom_okato);
CREATE INDEX boundary_polygon_osm_id ON boundary USING btree (polygon_osm_id);
CREATE INDEX boundary_polygon_oktmo ON boundary USING btree (oktmo);

DROP TABLE IF EXISTS boundary_is_in;

CREATE TABLE boundary_is_in
(
  parent integer,
  child integer
);

CREATE INDEX boundary_is_in_child  ON boundary_is_in USING btree (child);
CREATE INDEX boundary_is_in_parent ON boundary_is_in USING btree (parent);

$MD_INIT$ */


--@: log boundary extraction
--@: level +
TRUNCATE boundary;

INSERT INTO boundary (id, polygon_osm_id, name, admin_level, geom, name_all, oktmo_user)
SELECT 
  osm_id AS id,
  osm_id AS polygon_osm_id,
  COALESCE(name, place_name, '<noname>') AS name,
  CASE 
    WHEN admin_level ~ '[0-9]+' THEN admin_level::int 
    ELSE NULL
  END AS admin_level,
  way AS geom,
  CASE 
    WHEN name IS NULL THEN place_name 
    ELSE name 
  END || COALESCE(';' || alt_name, '') || COALESCE(';' || official_name, '') AS name_all,
  substring("oktmo:user" from 1 for 8) AS oktmo_user
FROM osm_polygon
WHERE boundary = 'administrative'
  AND admin_level ~ '[0-9]+'
  AND admin_level IN ('2', '3', '4', '5', '6', '7', '8', '9')
  AND NOT osm_id IN (-59065, -59161, -59092) -- анклавы РБ на территории РФ
  AND ST_IsValid(way);

--@: log boundary capitals
UPDATE boundary SET
  capital_point_osm_id = t.capital_point_osm_id
FROM (
    SELECT id,
           MIN(substring(members[i],2)::int) AS capital_point_osm_id
    FROM (
        SELECT b.id, members, generate_series(1, array_upper(members,1)) i 
        FROM boundary b INNER JOIN osm_rels r ON r.id = -b.polygon_osm_id
      ) t
    WHERE i % 2 = 1 AND substring(members[i],1,1) = 'n' AND members[i+1] IN ('admin_centre', 'capital', 'admin_center')
    GROUP BY id
  ) t 
WHERE t.id = boundary.id;

--@: log building hierarchy
TRUNCATE boundary_is_in;
  
INSERT INTO boundary_is_in (parent, child)
SELECT p.id, c.id
FROM boundary p, boundary c 
WHERE c.id <> p.id AND c.geom && p.geom AND ((ST_Within(c.geom, p.geom) AND NOT ST_Equals(c.geom, p.geom)) OR (ST_Equals(c.geom, p.geom) AND c.admin_level > p.admin_level));

UPDATE boundary SET parent = NULL;
UPDATE boundary SET
  parent = is_in.parent
FROM boundary b
  LEFT JOIN boundary_is_in is_in ON is_in.child = b.id
WHERE b.id = boundary.id AND NOT EXISTS(
  SELECT *
  FROM boundary_is_in ck1
    LEFT JOIN boundary_is_in ck2 ON ck1.child = ck2.parent
  WHERE ck1.parent = is_in.parent AND ck2.child = is_in.child
);

--@: level -
