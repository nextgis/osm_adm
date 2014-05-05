
CREATE OR REPLACE VIEW v_adm2_country AS 
 SELECT boundary_output.id, boundary_output.polygon_osm_id AS osm_id, boundary_output.osm_name AS name, boundary_output.osm_name_en AS name_en, boundary_output.name_lat, boundary_output.area, boundary_output.geom
   FROM boundary_output
  WHERE boundary_output.admin_level = 2;

CREATE OR REPLACE VIEW v_adm3_federal AS 
 SELECT boundary_output.id, boundary_output.polygon_osm_id AS osm_id, boundary_output.osm_name AS name, boundary_output.osm_name_en AS name_en, boundary_output.name_lat, boundary_output.area, boundary_output.geom
   FROM boundary_output
  WHERE boundary_output.admin_level = 3;

CREATE OR REPLACE VIEW v_adm4_region AS 
 SELECT boundary_output.id, boundary_output.polygon_osm_id AS osm_id, boundary_output.osm_name AS name, boundary_output.osm_name_en AS name_en, boundary_output.name_lat, boundary_output.area, boundary_output.okato_code AS okato, boundary_output.okato_name AS okato_n, boundary_output.oktmo_code AS oktmo, boundary_output.oktmo_name AS oktmo_n, boundary_output.geom
   FROM boundary_output
  WHERE boundary_output.admin_level = 4;

CREATE OR REPLACE VIEW v_adm6_district AS 
 SELECT boundary_output.id, boundary_output.polygon_osm_id AS osm_id, boundary_output.osm_name AS name, boundary_output.osm_name_en AS name_en, boundary_output.name_lat, boundary_output.area, boundary_output.okato_code AS okato, boundary_output.okato_name AS okato_n, boundary_output.oktmo_code AS oktmo, boundary_output.oktmo_name AS oktmo_n, boundary_output.geom
   FROM boundary_output
  WHERE boundary_output.admin_level = 6;