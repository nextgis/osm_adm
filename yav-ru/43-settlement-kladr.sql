/* $MD_INIT$
DROP TABLE IF EXISTS settlement_kladr;

CREATE TABLE settlement_kladr (
  settlement_id bigint,
  kladr_id bigint
);

$MD_INIT$ */

--@: log settlement kladr
TRUNCATE settlement_kladr;

INSERT INTO settlement_kladr
SELECT s.id, cladr.code 
  FROM settlement s
    INNER JOIN settlement_okato_match so ON s.id = so.obj_id 
    INNER JOIN okato ON okato.id = so.dict_id
    INNER JOIN cladr ON okatd = okato.code 
      AND cladr.obj_class = 'B'
      AND cladr.actuality='00'
      AND yav_normal_text(cladr.name) = ANY (
          (yav_name_variants(string_to_array(name_all, ';'), ARRAY[]::text[])).name);

UPDATE settlement SET kladr = sk.kladr_id
FROM settlement_kladr sk WHERE sk.settlement_id = settlement.id;
