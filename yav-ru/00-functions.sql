/* $MD_INIT$ 

--@: log function: yav_normal_text
CREATE OR REPLACE FUNCTION yav_normal_text(IN txt text) RETURNS text AS $SQL$
SELECT  trim(regexp_replace(regexp_replace(regexp_replace(regexp_replace(
        regexp_replace(regexp_replace(
        replace(lower($1), 'ё', 'е'),         -- ё -> е
        E'им\\.', 'имени ', 'g'),             -- сокращения из окато
        E'\\.', '. ', 'g'),                   -- пробел после точки
        E'(\\s|^)(№|n)(\\s|$)', ' ', 'g'),    -- знак номера и N
        E'[-"''№]', ' ', 'g'),                -- 
        E'\\s+', ' ', 'g'),                   -- двойные пробелы
        E'\\(.*\\)', ' ', 'g')                -- в скобках
        )
$SQL$ LANGUAGE sql IMMUTABLE COST 1000;

--@: log function: yav_sb_sk
DROP FUNCTION IF EXISTS yav_sb_sk();

DROP TYPE IF EXISTS status_key;
CREATE TYPE status_key AS (
  k text,
  v text
);

CREATE OR REPLACE FUNCTION yav_sb_sk() RETURNS SETOF status_key AS $SQL$
  SELECT CAST(t AS status_key)
  FROM unnest(ARRAY[
    ('субъект', 'область')::status_key,
    ('субъект', 'республика')::status_key,
    ('субъект', 'край')::status_key,
    ('субъект', 'автономная область')::status_key,
    ('субъект', 'автономный округ')::status_key,
    
    ('город', 'город курорт')::status_key,
    ('город', 'город герой')::status_key,
    ('город', 'городской округ')::status_key,
    ('город', 'город')::status_key,
    ('город', 'го')::status_key,

    ('район', 'муниципальный район')::status_key,
    ('район', 'район')::status_key,
    ('район', 'кожуун')::status_key,
    ('район', 'улус')::status_key,
    ('район', 'муниципальный округ')::status_key,
    ('район', 'округ')::status_key,
    ('район', 'мр')::status_key,

    ('городское поселение', 'сельское поселение')::status_key,
    ('городское поселение', 'городское поселение')::status_key,

    ('пгт', 'поселок городского типа')::status_key,
    ('пгт', 'пгт.')::status_key,
    
    ('поселок', 'дачный поселковый совет')::status_key,
    ('поселок', 'дачный поселок')::status_key,
    ('поселок', 'поселок')::status_key,
    ('поселок', 'пос.')::status_key,
    
    ('деревня', 'деревня')::status_key,
    ('деревня', 'дер.')::status_key,
    ('деревня', 'д.')::status_key,

    ('село', 'село')::status_key,
    ('село', 'с.')::status_key,

    ('хутор', 'хутор')::status_key,
    ('хутор', 'х.')::status_key,
    ('хутор', 'хут.')::status_key,

    ('слобода', 'слобода')::status_key,
    
    ('станица', 'станица')::status_key,
    
    ('аул', 'аул')::status_key
  ]) t
$SQL$ LANGUAGE sql IMMUTABLE COST 1000 ROWS 100;

--@: log function: yav_name_variants
DROP FUNCTION IF EXISTS yav_name_variants(text[], text[]);

DROP TYPE IF EXISTS name_variants;
CREATE TYPE name_variants AS (
  name text[],
  status text[]
);

CREATE OR REPLACE FUNCTION yav_name_variants(IN name text[], status text[]) RETURNS name_variants AS $SQL$
  SELECT ROW(
    (SELECT array_agg(i) FROM unnest(array_agg(t.name)) i WHERE i IS NOT NULL ), 
    (SELECT CASE 
       WHEN array_agg(i) = ARRAY[]::text[] THEN NULL
       ELSE array_agg(i)
     END
     FROM unnest(array_agg(t.status)) i
     WHERE i IS NOT NULL )
    )::name_variants
  FROM (
    SELECT
      trim(replace(' ' || name || ' ', ' ' || sk.v || ' ', ' ')) AS name,
      sk.k AS status
    FROM (SELECT yav_normal_text(unnest($1)) AS name) tmp 
      INNER JOIN yav_sb_sk() sk ON position(' ' || sk.v || ' ' in ' ' || name || ' ') > 0

    UNION 

    SELECT yav_normal_text(unnest($1)) AS name, NULL::text AS status

    UNION 

    SELECT NULL, sk.k AS status
    FROM (SELECT unnest($2) AS status) tmp 
      INNER JOIN yav_sb_sk() sk ON status = sk.v
    ) t
$SQL$ LANGUAGE sql IMMUTABLE COST 1000;

--@: log function: yav_translit

DROP FUNCTION IF EXISTS yav_translit(text);

CREATE OR REPLACE FUNCTION yav_translit(text) RETURNS text AS $SQL$
 SELECT replace( replace( replace( replace( replace( replace( replace( replace(
        replace( replace( replace( replace( replace( replace(
        replace( replace( replace( replace(
        translate($1, 'АБВГДЕЗИЙКЛМНОПРСТУФЦЪЫЬабвгдезийклмнопрстуфцъыь',
                       'ABVGDEZIJKLMNOPRSTUFC''Y''abvgdezijklmnoprstufc''y'''),
        'ё', 'jo'),
        'Ё', 'JO'),
        'ж', 'zh'),
        'Ж', 'ZH'),
        'х', 'kh'),
        'Х', 'KH'),
        'ч', 'ch'),
        'Ч', 'CH'),
        'ш', 'sh'),
        'Ш', 'SH'),
        'щ', 'shh'),
        'Щ', 'SHH'),
        'э', 'eh'),
        'Э', 'EH'),
        'ю', 'ju'),
        'Ю', 'JU'),
        'я', 'ja'),
        'Я', 'JA');
$SQL$ LANGUAGE sql IMMUTABLE COST 500;

--@: log spatial ref sys 95001
DELETE FROM spatial_ref_sys WHERE srid = 95001;
INSERT INTO spatial_ref_sys (srid, proj4text) VALUES (
  95001,
 '+proj=aea +lat_1=52 +lat_2=64 +lat_0=0 +lon_0=105 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs'
);

$MD_INIT$ */