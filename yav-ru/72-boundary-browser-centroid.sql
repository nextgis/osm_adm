/* $MD_INIT$

--@: log table: boundary_borwser_centroid

DROP TABLE IF EXISTS boundary_browser_centroid;

CREATE TABLE boundary_browser_centroid (
  boundary_src varchar(10),
  boundary_id bigint,
  centroid geometry,
  CONSTRAINT boundary_browser_centroid_pk PRIMARY KEY (boundary_src, boundary_id)
);

$MD_INIT$ */

--@: log boundary borwser centroid

SELECT sb.boundary_src, sb.boundary_id, ST_Centroid(ST_Collect(s.geom_point))
FROM settlement_browser sb INNER JOIN settlement s ON sb.src = 'osm' AND sb.id = s.id
GROUP BY sb.boundary_src, sb.boundary_id;