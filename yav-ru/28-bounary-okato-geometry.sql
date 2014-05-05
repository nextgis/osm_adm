--@: log boundary okato geometry

UPDATE boundary SET
  geom_okato = CASE WHEN ST_IsEmpty(t_boundary.geom) THEN NULL ELSE t_boundary.geom END
FROM (
  SELECT b.id AS id, COALESCE(ST_Difference(b.geom, ST_Union(bc.geom)), b.geom) AS geom 
  FROM boundary b 
    LEFT JOIN boundary bc ON bc.parent_oktmo = b.id AND bc.oktmo IS NOT NULL
    WHERE b.oktmo IS NOT NULL GROUP BY b.id, b.geom
) t_boundary
WHERE boundary.id = t_boundary.id;

