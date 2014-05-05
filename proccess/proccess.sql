DROP TABLE IF EXISTS is_in;
CREATE TEMP TABLE is_in
(
  parent integer,
  child integer
);

INSERT INTO is_in
SELECT p1.polygon_osm_id AS parent, p2.polygon_osm_id AS child
  FROM boundary p1 CROSS JOIN boundary p2
  WHERE p1.id <> p2.id
    AND ST_Within(p2.geom, p1.geom);

UPDATE boundary SET
  variants = name_variants_t(normalize_name("name_all"), '');

UPDATE boundary SET
  v_name = regexp_split_to_array(split_part(variants, '||', 1), ';'),
  v_status = regexp_split_to_array(split_part(variants, '||', 2), ';');

DROP TABLE IF EXISTS oktmo_dict;
DROP TABLE IF EXISTS oktmo_obj;
DROP TABLE IF EXISTS oktmo_out;

CREATE TEMP TABLE oktmo_dict (
  id int, 
  scope int,
  v_name text[],
  v_status text[],
  user_hint text,
  uniq_name boolean,
  uniq_full boolean,
  uniq_hint boolean,
  flag boolean
);


CREATE TEMP TABLE oktmo_obj (
  id int, 
  scope int,
  v_name text[],
  v_status text[],
  user_hint text,
  uniq_name boolean,
  uniq_full boolean,
  uniq_hint boolean,
  flag boolean
);

CREATE TEMP TABLE oktmo_out (
  scope int,
  dict_id int,
  obj_id int,
  source char(1)
);

TRUNCATE oktmo_dict;
TRUNCATE oktmo_obj;
TRUNCATE oktmo_out;


INSERT INTO oktmo_dict
SELECT id,
  0 AS scope,
  regexp_split_to_array(split_part(name_variants_t(normalize_name(COALESCE(okato.raw, oktmo.simple_name)), ''), '||', 1), ';'),
  regexp_split_to_array(split_part(name_variants_t(normalize_name(COALESCE(okato.raw, oktmo.simple_name)), CASE 
    WHEN okato.cls = 'мр' THEN 'район'
    WHEN okato.cls = 'го' THEN 'город'
    WHEN okato.cls = 'сп' THEN 'сп'
    WHEN okato.cls = 'гп' THEN 'гп'
    ELSE '' END), '||', 2), ';'), 
  oktmo.code
FROM oktmo
  -- для субъектов берем наимановние из ОКАТО
  LEFT JOIN oktmo_to_okato o2o ON o2o.okato = oktmo.code
  LEFT JOIN okato okato ON okato.code = o2o.okato
WHERE oktmo.is_subject;

INSERT INTO oktmo_obj
SELECT id, 0 AS scope, v_name, v_status, oktmo_user
FROM boundary
WHERE boundary.admin_level = 4;

SELECT yav_oktmo_cross_stage();

/* === Уровень 2 ===  */

TRUNCATE oktmo_dict;
TRUNCATE oktmo_obj;
TRUNCATE oktmo_out;

INSERT INTO oktmo_dict
SELECT tab_oktmo.id, boundary.id,
  regexp_split_to_array(split_part(name_variants_t(normalize_name("simple_name"), ''), '||', 1), ';'),
  regexp_split_to_array(split_part(name_variants_t(normalize_name("simple_name"), CASE 
    WHEN cls = 'мр' THEN 'район'
    WHEN cls = 'го' THEN 'город'
    WHEN cls = 'сп' THEN 'сп'
    WHEN cls = 'гп' THEN 'гп'
    ELSE '' END), '||', 2), ';'),
  code
FROM oktmo tab_oktmo
  LEFT JOIN boundary ON boundary.oktmo = tab_oktmo.parent_obj
WHERE not tab_oktmo.is_group AND boundary.id IS NOT NULL;

INSERT INTO oktmo_obj
SELECT tab_child.id AS id, tab_parent.id AS scope, tab_child.v_name, tab_child.v_status, tab_child.oktmo_user
FROM boundary tab_parent
    LEFT JOIN is_in ON tab_parent.polygon_osm_id = is_in.parent
    LEFT JOIN boundary tab_child ON is_in.child = tab_child.polygon_osm_id
WHERE tab_parent.admin_level = 4
 AND (tab_child.admin_level = 6 OR (tab_parent.oktmo IN ('40000000', '45000000') AND tab_child.admin_level = 8))
 AND tab_parent.oktmo IS NOT NULL;

SELECT yav_oktmo_cross_stage();