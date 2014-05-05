/* $MD_INIT$

--@: log settlement gns
DROP TABLE IF EXISTS settlement_gns;
CREATE TABLE settlement_gns
(
  settlement_id integer NOT NULL,
  CONSTRAINT settlement_gns_pk PRIMARY KEY (settlement_id)
);

$MD_INIT$ */

--@: log settlement gns
TRUNCATE settlement_gns;

DROP TABLE IF EXISTS tmp_settlement_snap;
CREATE TEMP TABLE tmp_settlement_snap (
  id bigint,
  geom geometry);

CREATE INDEX tmp_settlement_snap_geom_idx ON tmp_settlement_snap USING gist (geom);

INSERT INTO tmp_settlement_snap
SELECT id, ST_SnapToGrid(geom_point, 0.000001) FROM settlement WHERE point_osm_id IS NOT NULL;

INSERT INTO settlement_gns
SELECT DISTINCT s.id
FROM tmp_settlement_snap s, gns
WHERE  s.geom && gns.geom
  AND s.geom = gns.geom;
