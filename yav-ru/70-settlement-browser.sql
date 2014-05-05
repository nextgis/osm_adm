/* $MD_INIT$ 

--@: log table: settlement_browser 

DROP TABLE IF EXISTS settlement_browser;

CREATE TABLE settlement_browser
(
  src character varying(10) NOT NULL,
  id bigint NOT NULL,
  boundary_src character varying(10),
  boundary_id integer,
  "name" character varying(255),
  place varchar(50),
  settlement_v_name text,
  settlement_v_status text,
  grp varchar(10),
  point_osm_id integer,
  polygon_osm_id integer,
  okato_id bigint,
  okato_match_mode varchar(10),
  okato_code character varying(11),
  okato_cls character varying(10),
  okato_name varchar(100),
  okato_st varchar(100),
  -- okato_v_name text,
  -- okato_v_status text,
  kladr_code varchar(17),
  status character varying(10),
  tip_vplace boolean,
  tip_noname_polygon boolean,
  CONSTRAINT settlement_browser_pkey PRIMARY KEY (src, id)
);

CREATE INDEX settlement_browser_boundary_idx
  ON settlement_browser
  USING btree
  (boundary_src, boundary_id);

CREATE INDEX settlement_browser_okato_id_idx
  ON settlement_browser
  USING btree
  (okato_id);

$MD_INIT$ */

--@: log settlement browser 

TRUNCATE settlement_browser;

INSERT INTO settlement_browser
            ( src, id, boundary_src, boundary_id, name,
              place, grp, point_osm_id, polygon_osm_id,
              okato_id, okato_match_mode, kladr_code, status )

  SELECT 'osm'::text, settlement.id ,
    CASE
      WHEN boundary_browser.src IS NOT NULL THEN boundary_browser.src
      ELSE 'polygon'::text
    END, 
    CASE
      WHEN boundary_browser.id IS NOT NULL THEN boundary_browser.id
      ELSE settlement.parent_boundary_oktmo
    END, 
    settlement.name,
    settlement.place,
    CASE WHEN okato.lvl = 2 OR settlement.place IN ('city', 'town') THEN 'mjr' ELSE 'mnr' END,
    settlement.point_osm_id,
    settlement.polygon_osm_id,
    okato.id,
    okato_match.m,
    settlement.kladr,
    CASE 
      --WHEN okato_match.settlement_id IS NULL THEN 'skipped'
      WHEN okato.code IS NOT NULL THEN 'match'
      WHEN okato_multiple.obj_id IS NOT NULL THEN 'unknown'
      WHEN okato.code IS NULL THEN 'mismatch'
      ELSE NULL 
    END AS status
  FROM settlement
    LEFT JOIN settlement_okato_match okato_match ON okato_match.obj_id = settlement.id
    LEFT JOIN okato ON okato.id = okato_match.dict_id
    LEFT JOIN oktmo_okato ON oktmo_okato.okato = okato.code AND is_in = TRUE
    LEFT JOIN oktmo ON oktmo.code = oktmo_okato.oktmo
    LEFT JOIN boundary_browser ON oktmo_code = oktmo.code
    LEFT JOIN (SELECT DISTINCT obj_id FROM settlement_okato_multiple) okato_multiple ON okato_multiple.obj_id = settlement.id

/*
  UNION

  SELECT DISTINCT 
    'osm'::text, settlement.id ,
    'polygon'::text, 
    okato_match.scope, 
    settlement.name,
    settlement.place,
    CASE WHEN settlement.place IN ('city', 'town') THEN 'mjr' ELSE 'mnr' END,
    settlement.point_osm_id,
    settlement.polygon_osm_id,
    --NULL,
    NULL::bigint AS okato_id,
    NULL,
    'unknown' AS status,
  	tip_vplace, tip_noname_polygon
  FROM okato_match
    LEFT JOIN settlement ON settlement_id = settlement.id
    -- LEFT JOIN okato ON okato.id = okato_match.okato_id
    -- LEFT JOIN oktmo_okato ON oktmo_okato.okato = okato.code AND is_in = TRUE
    -- LEFT JOIN oktmo ON oktmo.code = oktmo_okato.oktmo
    -- LEFT JOIN boundary_browser ON oktmo_code = oktmo.code
  WHERE okato_match.okato_id IS NULL AND f_unknown
*/

  UNION

  SELECT 'okato'::text, okato.id,
    CASE
      WHEN boundary_browser.src IS NOT NULL THEN boundary_browser.src
      ELSE 'oktmo'::text
    END, 
    CASE
      WHEN boundary_browser.id IS NOT NULL THEN boundary_browser.id
      ELSE oktmo.id
    END, 
    okato.name,
    NULL, 
    CASE WHEN okato.lvl = 2 THEN 'mjr' ELSE 'mnr' END,
    NULL, NULL,
    okato.id,
    NULL,
    NULL,
    CASE
      WHEN okato_multiple.dict_id IS NOT NULL THEN 'unknown'
      ELSE 'none'
    END AS status
  FROM settlement_okato_dict okato_dict
    LEFT JOIN okato ON okato_dict.id = okato.id
    LEFT JOIN oktmo_okato ON oktmo_okato.okato = okato.code AND is_in = TRUE
    LEFT JOIN oktmo ON oktmo.code = oktmo_okato.oktmo
    LEFT JOIN boundary_browser ON oktmo_code = oktmo.code
    LEFT JOIN (SELECT DISTINCT dict_id FROM settlement_okato_multiple) okato_multiple ON okato_multiple.dict_id = okato_dict.id
  WHERE NOT okato_dict.has_match;

UPDATE settlement_browser SET
  okato_code = okato.code,
  okato_cls = okato.cls,
  okato_name = okato.name,
  okato_st = okato.status
  --okato_v_name = normalize_name(okato.name),
  --okato_v_status = COALESCE(simple_status.simple, okato.status)
FROM okato LEFT JOIN okato_simple_status simple_status ON simple_status.full = okato.status WHERE okato.id = okato_id;

/* UPDATE settlement_browser sb SET 
  settlement_v_name = array_to_string(v_name, ';'),
  settlement_v_status = array_to_string(v_status, ';')
FROM settlement WHERE sb.src = 'osm' AND sb.id = settlement.id; */

-- SELECT * FROM oktmo_okato WHERE is_in = True

-- SELECT * FROM (SELECT okato FROM oktmo_okato GROUP BY okato HAVING COUNT(oktmo) > 1) o LEFT JOIN settlement ON settlement.okato = o.okato