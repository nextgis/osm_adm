SELECT   osm_id AS polygon_osm_id,   COALESCE(name, place_name) AS name,   CASE     WHEN admin_level ~ '[0-9]+' THEN admin_level::int     ELSE NULL  END AS admin_level,  ST_Union(way) AS geom,  CASE     WHEN name IS NULL THEN place_name     ELSE name   END || COALESCE(';' || alt_name, '') || COALESCE(';' || official_name, '') AS name_all,  "oktmo:user" AS oktmo_user, "name:en" AS name_en  FROM osm_polygon WHERE boundary = 'administrative'  AND (name IS NOT NULL OR place_name IS NOT NULL)  AND admin_level ~ '[0-9]+'  AND admin_level IN ('2', '3', '4', '6') AND ST_IsValid(way) GROUP BY admin_level, polygon_osm_id, name, place_name,alt_name,official_name,"oktmo:user", "name:en" 