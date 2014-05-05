--@: log boundary oktmo hierarchy
--@: level +

--@: log parents
UPDATE boundary SET
  parents = p.parents
FROM (
  SELECT child, array_agg(parent) AS parents FROM boundary_is_in
  GROUP BY child
) p
WHERE p.child = polygon_osm_id;
UPDATE boundary SET parent_oktmo = NULL WHERE parent_oktmo = 0;

UPDATE boundary SET parents_oktmo = ARRAY[parent_oktmo];

UPDATE boundary SET parents_oktmo = bp.parent_oktmo || boundary.parents_oktmo
FROM boundary bp WHERE bp.id = boundary.parents_oktmo[1] AND bp.parent_oktmo IS NOT NULL;

UPDATE boundary SET parents_oktmo = bp.parent_oktmo || boundary.parents_oktmo 
FROM boundary bp WHERE bp.id = boundary.parents_oktmo[1] AND bp.parent_oktmo IS NOT NULL;

UPDATE boundary SET parents_oktmo = bp.parent_oktmo || boundary.parents_oktmo
FROM boundary bp WHERE bp.id = boundary.parents_oktmo[1] AND bp.parent_oktmo IS NOT NULL;

--@: log childs
UPDATE boundary SET
  childs_oktmo = (SELECT array_agg(bc.id) FROM boundary bc WHERE boundary.id = ANY (bc.parents_oktmo));

UPDATE boundary SET childs_oktmo = NULL
WHERE array_upper(childs_oktmo, 1) IS NULL;

--@: level -