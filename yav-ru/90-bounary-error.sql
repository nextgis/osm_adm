/* $MD_INIT$

--@: log table: boundary_error

DROP TABLE IF EXISTS boundary_error;
CREATE TABLE boundary_error (
  id integer NOT NULL,
  tp varchar(25),
  related text[],
  geom_point geometry,
  settlement int[],
  boundary int[],
  CONSTRAINT boundary_error_pk PRIMARY KEY (id)
);

--@: sequence: boundary_error_id_seq
DROP SEQUENCE IF EXISTS boundary_error_id_seq;
CREATE SEQUENCE boundary_error_id_seq;
ALTER TABLE boundary_error ALTER COLUMN id SET DEFAULT nextval('boundary_error_id_seq'::regclass);

--@: log table: boundary_error_browser 

DROP TABLE IF EXISTS boundary_error_browser;
CREATE TABLE boundary_error_browser (
  id integer,
  tp varchar(25),
  boundary_src varchar(10),
  boundary_id integer,
  related text[]
);

DROP TABLE IF EXISTS boundary_error_browser_settlement;
CREATE TABLE boundary_error_browser_settlement (
  boundary_error_id integer,
  settlement_id integer,
  CONSTRAINT boundary_error_browser_settlement_pk PRIMARY KEY (boundary_error_id, settlement_id)
);

CREATE INDEX boundary_error_browser_boundary_settlement_id_idx
  ON boundary_error_browser_settlement
  USING btree
  (settlement_id);


DROP TABLE IF EXISTS boundary_error_browser_boundary;
CREATE TABLE boundary_error_browser_boundary (
  boundary_error_id integer,
  boundary_id integer,
  CONSTRAINT boundary_error_browser_boundary_pk PRIMARY KEY (boundary_error_id, boundary_id)
);

CREATE INDEX boundary_error_browser_boundary_boundary_id_idx
  ON boundary_error_browser_boundary
  USING btree
  (boundary_id);


$MD_INIT$ */

--@: log boundary error  
--@: level +

TRUNCATE boundary_error;

--@: log S-OVERLAP
INSERT INTO boundary_error(tp, geom_point, settlement)
SELECT 'S-OVERLAP', ST_PointOnSurface(ST_Intersection(s1.geom_polygon, s2.geom_polygon)), ARRAY[s1.id, s2.id]
FROM settlement s1 LEFT JOIN settlement s2 ON
  s1.id < s2.id AND s1.geom_polygon && s2.geom_polygon AND ST_Overlaps(s1.geom_polygon, s2.geom_polygon)
WHERE s1.geom_polygon IS NOT NULL AND s2.id IS NOT NULL;

-- точка НП внутри другого полигона НП
--@: log S-WITHIN
INSERT INTO boundary_error(tp, geom_point, settlement)
SELECT 'S-WITHIN', s1.geom_point, ARRAY[s1.id, s2.id]
FROM settlement s1 LEFT JOIN settlement s2 ON
  ST_Within(s1.geom_point, s2.geom_polygon)
WHERE s1.polygon_osm_id IS NULL AND s2.polygon_osm_id IS NOT NULL;

-- вложенные НП
--@: log S-WITHIN
INSERT INTO boundary_error(tp, geom_point, settlement)
SELECT 'S-WITHIN', ST_PointOnSurface(ST_Intersection(s1.geom_polygon, s2.geom_polygon)), ARRAY[s1.id, s2.id]
FROM settlement s1, settlement s2
WHERE s1.polygon_osm_id IS NOT NULL AND s2.polygon_osm_id IS NOT NULL AND s1.id <> s2.id 
  AND s1.geom_polygon && s2.geom_polygon AND ST_Within(s1.geom_polygon, s2.geom_polygon);

-- НП с разными тегами place для полигона и точки
--@: log S-VPLACE
/* INSERT INTO boundary_error(tp, geom_point, settlement)
SELECT 'S-VPLACE', s.geom_point, ARRAY[s.id]
FROM settlement s
WHERE tip_vplace; */

-- полигон без имени
--@: log S-NONAMEP
/* INSERT INTO boundary_error(tp, geom_point, settlement)
SELECT 'S-NONAMEP', s.geom_point, ARRAY[s.id]
FROM settlement s
WHERE tip_noname_polygon; */

-- пересечение полигона НП с адм. границей
--@: log SB-OVERLAP
INSERT INTO boundary_error (tp, geom_point, settlement, boundary)
SELECT 'SB-OVERLAP', ST_PointOnSurface(ST_Intersection(s.geom_polygon, b.geom)), ARRAY[s.id], ARRAY[b.id]
FROM boundary b, settlement s
WHERE b.admin_level >= 6 AND s.geom_polygon && b.geom AND ST_Intersects(s.geom_polygon, b.geom) AND ST_Overlaps(s.geom_polygon, b.geom);

-- пересечение границ
--@: log B-OVERLAP
INSERT INTO boundary_error(tp, geom_point, boundary)
SELECT 'B-OVERLAP', ST_PointOnSurface(ST_Intersection(b1.geom, b2.geom)), ARRAY[b1.id, b2.id]
FROM boundary b1, boundary b2
WHERE b1.admin_level >= 4 AND b2.admin_level >= 4 AND b1.id > b2.id AND  b1.geom && b2.geom AND ST_Overlaps(b1.geom, b2.geom);

--@: log S-GNS
INSERT INTO boundary_error(tp, geom_point, settlement)
SELECT 'S-GNS', s.geom_point, ARRAY[s.id]
FROM settlement s, settlement_gns
WHERE s.id = settlement_gns.settlement_id;

-- вложенная граница имеет такой же или больший уровень
--@: log B-BAD-LEVEL
INSERT INTO boundary_error(tp, geom_point, boundary)
SELECT 'B-BAD-LEVEL', ST_PointOnSurface(c.geom), ARRAY[p.id, c.id]
FROM boundary_is_in is_in
  LEFT JOIN boundary p ON is_in.parent = p.id
  LEFT JOiN boundary c ON is_in.child = c.id
WHERE p.admin_level > 2 AND c.admin_level <= p.admin_level;

-- гранцы совпадают
--@: log B-EQUALS
INSERT INTO boundary_error(tp, geom_point, boundary)
SELECT 'B-EQUALS', ST_PointOnSurface(b1.geom), ARRAY[b1.id, b2.id]
FROM boundary b1, boundary b2
WHERE b1.id > b2.id AND b1.admin_level > 5 AND b2.admin_level > 5 AND b1.geom && b2.geom AND ST_Equals(b1.geom, b2.geom);


--@: log B-CAP-NS
INSERT INTO boundary_error(tp, geom_point, boundary)
SELECT 'B-CAP-NS', ST_PointOnSurface(b.geom), ARRAY[b.id]
FROM boundary b LEFT JOIN settlement s ON b.capital_point_osm_id = s.point_osm_id
WHERE b.capital_point_osm_id IS NOT NULL AND s.id IS NULL;


-- странный статус
--@: log S-STATUS
INSERT INTO boundary_error(tp, geom_point, settlement)
SELECT 'S-STATUS', s.geom_point, ARRAY[s.id]
FROM settlement_browser sb INNER JOIN settlement s ON sb.id = s.id
WHERE (sb.okato_cls IN ('нп') AND sb.place IN ('city'))
  OR (sb.okato_cls IN ('город', 'пгт') AND sb.place IN ('hamlet'));


--@: log S-LAT-MIX
INSERT INTO boundary_error(tp, geom_point, settlement)
SELECT 'S-LAT-MIX', s.geom_point, array[s.id]
FROM settlement s
WHERE name ~ '.*[a-zA-Z][а-яА-Я].*' OR name ~ '.*[а-яА-Я][a-zA-Z].*';

--@: level -

--@: log boundary error browser
TRUNCATE boundary_error_browser;
TRUNCATE boundary_error_browser_settlement;
TRUNCATE boundary_error_browser_boundary;

INSERT INTO boundary_error_browser (id, tp, boundary_src, boundary_id, related)
SELECT be.id, be.tp, 'polygon', b.id,  be.related
  FROM boundary_error be 
    LEFT JOIN boundary b ON ST_Intersects(be.geom_point, b.geom_okato);

INSERT INTO boundary_error_browser_settlement 
SELECT DISTINCT boundary_error.id, settlement[idx]
FROM boundary_error 
  INNER JOIN (
    SELECT id, generate_series(1, array_upper(settlement,1 )) AS idx
    FROM boundary_error
  ) i ON i.id = boundary_error.id AND settlement[idx] IS NOT NULL;

INSERT INTO boundary_error_browser_boundary 
SELECT DISTINCT boundary_error.id, boundary[idx]
FROM boundary_error 
  INNER JOIN (
    SELECT id, generate_series(1, array_upper(boundary,1 )) AS idx
    FROM boundary_error
  ) i ON i.id = boundary_error.id AND boundary[idx] IS NOT NULL;
