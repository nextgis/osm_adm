--@: log settlement boundary oktmo
UPDATE settlement SET
  parent_boundary_oktmo = boundary.id,
  parent_boundary_oktmo_polygon_osm_id = boundary.polygon_osm_id
FROM (
    SELECT * FROM boundary
  ) boundary
WHERE settlement.geom_point && boundary.geom_okato 
  AND  ST_Within(settlement.geom_point, boundary.geom_okato);
