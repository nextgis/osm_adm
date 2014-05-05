/* $MD_INIT$ 

--@: log table: boundary_oktmo

DROP TABLE IF EXISTS boundary_oktmo;
CREATE TABLE boundary_oktmo
(
  boundary integer NOT NULL,
  oktmo integer,
  src character(1),
  CONSTRAINT boundary_oktmo_pk PRIMARY KEY (boundary)
);

CREATE INDEX boundary_oktmo_boundary  ON boundary_oktmo  USING btree (boundary);
CREATE INDEX boundary_oktmo_oktmo ON boundary_oktmo USING btree (oktmo);

--@: log function: yav_boundary_oktmo_mfc

DROP FUNCTION IF EXISTS yav_boundary_oktmo_mfc();
CREATE OR REPLACE FUNCTION yav_boundary_oktmo_mfc() RETURNS void AS $PGSQL$ 
BEGIN
  UPDATE oktmo_dict t SET uniq_hint = th.id IS NULL AND t.user_hint IS NOT NULL
  FROM oktmo_dict cp 
    LEFT JOIN oktmo_dict th ON th.id <> cp.id 
              AND th.scope = cp.scope 
              AND th.user_hint = cp.user_hint
              AND th.flag IS NULL
  WHERE t.flag IS NULL AND cp.id = t.id;

  UPDATE oktmo_obj t SET uniq_hint = th.id IS NULL AND t.user_hint IS NOT NULL
  FROM oktmo_obj cp 
    LEFT JOIN oktmo_obj th ON th.id <> cp.id 
                              AND th.scope = cp.scope 
                              AND th.user_hint = cp.user_hint
                              AND th.flag IS NULL
  WHERE t.flag IS NULL AND cp.id = t.id;

  INSERT INTO oktmo_out
  SELECT td.scope, td.id, tb.id, 'H'
  FROM oktmo_dict td CROSS JOIN oktmo_obj tb
  WHERE td.scope = tb.scope AND td.uniq_hint AND tb.uniq_hint
    AND td.flag IS NULL AND tb.flag IS NULL
    AND td.user_hint = tb.user_hint;

  UPDATE oktmo_dict SET flag = true FROM oktmo_out WHERE id = dict_id;
  UPDATE oktmo_obj SET flag = true FROM oktmo_out WHERE id = obj_id;

  UPDATE oktmo_dict t SET
    uniq_full = tf.id IS NULL
  FROM oktmo_dict cp 
    LEFT JOIN oktmo_dict tf ON tf.id <> cp.id 
              AND tf.scope = cp.scope
              AND tf.flag IS NULL
              AND tf.v_status && cp.v_status
              AND tf.v_name && cp.v_name
  WHERE t.flag IS NULL AND cp.id = t.id;

  UPDATE oktmo_obj t SET
    uniq_full = tf.id IS NULL
  FROM oktmo_obj cp 
    LEFT JOIN oktmo_obj tf ON tf.id <> cp.id
              AND tf.scope = cp.scope
              AND tf.flag IS NULL
              AND tf.v_status && cp.v_status
              AND tf.v_name && cp.v_name
  WHERE t.flag IS NULL AND cp.id = t.id;

  INSERT INTO oktmo_out
  SELECT td.scope, td.id, tb.id, 'F' FROM oktmo_dict td CROSS JOIN oktmo_obj tb
  WHERE td.scope = tb.scope AND td.uniq_full AND tb.uniq_full
    AND td.flag IS NULL AND tb.flag IS NULL
    AND td.v_name && tb.v_name AND td.v_status && tb.v_status ;

  UPDATE oktmo_dict SET flag = true FROM oktmo_out WHERE id = dict_id;
  UPDATE oktmo_obj SET flag = true FROM oktmo_out WHERE id = obj_id;

  UPDATE oktmo_dict t SET
    uniq_name = tf.id IS NULL
  FROM oktmo_dict cp 
    LEFT JOIN oktmo_dict tf ON tf.id <> cp.id
              AND tf.scope = cp.scope
              AND tf.flag IS NULL 
              AND tf.v_name && cp.v_name
  WHERE t.flag IS NULL AND cp.id = t.id;

  UPDATE oktmo_obj t SET
    uniq_name = tf.id IS NULL
  FROM oktmo_obj cp 
    LEFT JOIN oktmo_obj tf ON tf.id <> cp.id AND tf.scope = cp.scope  AND tf.flag IS NULL 
              AND tf.v_name && cp.v_name
  WHERE t.flag IS NULL AND cp.id = t.id;

  INSERT INTO oktmo_out
  SELECT td.scope, td.id, tb.id, 'N' FROM oktmo_dict td CROSS JOIN oktmo_obj tb
  WHERE td.scope = tb.scope AND td.uniq_name AND tb.uniq_name
    AND td.flag IS NULL AND tb.flag IS NULL
    AND td.v_name && tb.v_name ;

  UPDATE oktmo_dict SET flag = true FROM oktmo_out WHERE id = dict_id;
  UPDATE oktmo_obj SET flag = true FROM oktmo_out WHERE id = obj_id;

  UPDATE boundary SET
    oktmo = tab_oktmo.code,
    oktmo_name = tab_oktmo.raw,
    parent_oktmo = tab.scope
  FROM oktmo_out tab
    LEFT JOIN oktmo tab_oktmo ON tab_oktmo.id = tab.dict_id
  WHERE tab.obj_id = boundary.id;

  INSERT INTO oktmo_match (scope, oktmo_id, boundary_id, src)
    SELECT scope, dict_id, obj_id, source FROM oktmo_out
    UNION
    SELECT scope, id, NULL, NULL FROM oktmo_dict WHERE flag IS NULL
  
  UNION
  
  SELECT scope, NULL, id, NULL FROM oktmo_obj WHERE flag IS NULL;

  RETURN;

END;$PGSQL$ LANGUAGE 'plpgsql' VOLATILE COST 1000;

$MD_INIT$ */

--@: log boundary oktmo
--@: level +

--@: log proccessing boundary names and statuses
UPDATE boundary
SET v_name   = tmp.name,
    v_status = tmp.status
FROM (
  SELECT id, (yav_name_variants(string_to_array(name_all, ';'), ARRAY[]::text[])).*
  FROM boundary
) tmp
WHERE tmp.id = boundary.id;

--@: log creating temporary tables
DROP TABLE IF EXISTS oktmo_match;
CREATE TEMP TABLE oktmo_match
(
  scope integer,
  oktmo_id integer,
  boundary_id integer,
  src character(1)
);

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

--@: log stage 1

TRUNCATE oktmo_dict;
TRUNCATE oktmo_obj;
TRUNCATE oktmo_out;

INSERT INTO oktmo_dict
SELECT oktmo.id,
  0 AS scope,
  (yav_name_variants(
    string_to_array(COALESCE(okato.raw, oktmo.simple_name), ';'),
     ARRAY[
      CASE 
        WHEN oktmo.cls = 'мр' THEN 'район'
        WHEN oktmo.cls = 'го' THEN 'город'
        WHEN oktmo.cls = 'сп' THEN 'сп'
        WHEN oktmo.cls = 'гп' THEN 'гп'
        ELSE ''
      END
     ]::text[])
  ).*,
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

SELECT yav_boundary_oktmo_mfc();

/* === Уровень 2 ===  */

--@: log stage 2

TRUNCATE oktmo_dict;
TRUNCATE oktmo_obj;
TRUNCATE oktmo_out;

INSERT INTO oktmo_dict
SELECT tab_oktmo.id, boundary.id,
  (yav_name_variants(
    string_to_array(COALESCE(okato.raw, tab_oktmo.simple_name), ';'),
     ARRAY[
      CASE 
        WHEN tab_oktmo.cls = 'мр' THEN 'район'
        WHEN tab_oktmo.cls = 'го' THEN 'город'
        WHEN tab_oktmo.cls = 'сп' THEN 'сп'
        WHEN tab_oktmo.cls = 'гп' THEN 'гп'
        ELSE ''
      END
     ]::text[])
  ).*,
 -- regexp_split_to_array(split_part(name_variants_t(normalize_name(CASE WHEN tab_oktmo.cls='тгфз' THEN COALESCE(okato.raw, simple_name) ELSE simple_name END), ''), '||', 1), ';'),
 -- regexp_split_to_array(split_part(name_variants_t(normalize_name(CASE WHEN tab_oktmo.cls='тгфз' THEN COALESCE(okato.raw, simple_name) ELSE simple_name END), CASE 
 --   WHEN tab_oktmo.cls = 'тгфз' THEN ''
 --   WHEN tab_oktmo.cls = 'мр' THEN 'район'
 --   WHEN tab_oktmo.cls = 'го' THEN 'город'
    -- WHEN tab_oktmo.cls = 'сп' THEN 'сп'
    -- WHEN tab_oktmo.cls = 'гп' THEN 'гп'
    -- ELSE '' END), '||', 2), ';'),
  tab_oktmo.code
FROM oktmo tab_oktmo
  LEFT JOIN boundary ON boundary.oktmo = tab_oktmo.parent_obj
  -- для ТГФЗ названия берем из ОКАТО
  LEFT JOIN oktmo_to_okato o2o ON tab_oktmo.cls IN ('тгфз') AND o2o.oktmo = tab_oktmo.code
  LEFT JOIN okato okato ON okato.code = o2o.okato
WHERE not tab_oktmo.is_group AND boundary.id IS NOT NULL;

INSERT INTO oktmo_obj
SELECT tab_child.id AS id, tab_parent.id AS scope, tab_child.v_name, tab_child.v_status, tab_child.oktmo_user
FROM boundary tab_parent
    LEFT JOIN boundary_is_in is_in ON tab_parent.polygon_osm_id = is_in.parent
    LEFT JOIN boundary tab_child ON is_in.child = tab_child.polygon_osm_id
WHERE tab_parent.admin_level = 4
 AND (tab_child.admin_level = 6 OR (tab_parent.oktmo IN ('40000000', '45000000') AND tab_child.admin_level = 8))
 AND tab_parent.oktmo IS NOT NULL;

SELECT yav_boundary_oktmo_mfc();

/* === Уровень 3 === */

--@: log stage 3

TRUNCATE oktmo_dict;
TRUNCATE oktmo_obj;
TRUNCATE oktmo_out;

INSERT INTO oktmo_dict
SELECT tab_oktmo.id, boundary.id, 
  (yav_name_variants(
    string_to_array(tab_oktmo.simple_name, ';'),
     ARRAY[
      CASE 
        WHEN tab_oktmo.cls = 'мр' THEN 'район'
        WHEN tab_oktmo.cls = 'го' THEN 'город'
        WHEN tab_oktmo.cls = 'сп' THEN 'сп'
        WHEN tab_oktmo.cls = 'гп' THEN 'гп'
        ELSE ''
      END
     ]::text[])
  ).*,
  -- regexp_split_to_array(split_part(name_variants_t(normalize_name(raw), ''), '||', 1), ';'),
  -- regexp_split_to_array(split_part(name_variants_t(normalize_name(raw), CASE 
  --   WHEN cls = 'мр' THEN 'район'
  --   WHEN cls = 'го' THEN 'город'
  --   WHEN cls = 'сп' THEN 'сп'
  --   WHEN cls = 'гп' THEN 'гп'
  --   ELSE '' END), '||', 2), ';'),
  code
FROM oktmo tab_oktmo LEFT JOIN boundary ON boundary.oktmo = tab_oktmo.parent_obj
WHERE (lvl = 3 AND cls<>'тгфз') AND boundary.id IS NOT NULL;

INSERT INTO oktmo_obj
SELECT tab_child.id AS id, tab_parent.id AS scope, tab_child.v_name, tab_child.v_status, tab_child.oktmo_user
FROM boundary tab_parent
    LEFT JOIN boundary_is_in is_in ON tab_parent.polygon_osm_id = is_in.parent
    LEFT JOIN boundary tab_child ON is_in.child = tab_child.polygon_osm_id
WHERE tab_parent.admin_level = 6
  AND tab_child.admin_level = 8
  AND tab_parent.oktmo IS NOT NULL;

SELECT yav_boundary_oktmo_mfc();

/* === */

TRUNCATE boundary_oktmo;

INSERT INTO boundary_oktmo 
SELECT boundary_id AS boundary, MIN(oktmo_id) AS oktmo, MIN(src)
FROM oktmo_match WHERE boundary_id IS NOT NULL
GROUP BY boundary_id;

--@: level -