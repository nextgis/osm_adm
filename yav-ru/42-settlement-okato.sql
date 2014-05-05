/* $MD_INIT$

--@: log table: settlement_okato_match)

DROP TABLE IF EXISTS  settlement_okato_match;
CREATE TABLE settlement_okato_match (
  obj_id bigint,
  dict_id bigint,
  m varchar(10)
);

--@: log table: settlement_okato_obj

DROP TABLE IF EXISTS settlement_okato_obj;
CREATE TABLE settlement_okato_obj (
  id bigint,
  has_match boolean
);

--@: log table: settlement_okato_dict

DROP TABLE IF EXISTS settlement_okato_dict;
CREATE TABLE settlement_okato_dict (
  id bigint,
  has_match boolean
);

CREATE UNIQUE INDEX idx_settlement_okato_match_obj_id ON settlement_okato_match (obj_id);
CREATE UNIQUE INDEX idx_settlement_okato_match_dict_id ON settlement_okato_match (dict_id);

--@: log table: settlement_okato_multiple

DROP TABLE IF EXISTS settlement_okato_multiple;
CREATE TABLE settlement_okato_multiple
(
  obj_id bigint,
  dict_id bigint,
  m character varying(10)
); 

CREATE INDEX settlement_okato_multiple_dict_id  ON settlement_okato_multiple  (dict_id);
CREATE INDEX settlement_okato_multiple_obj_id  ON settlement_okato_multiple (obj_id);



--@: log table: okato_simple_status
DROP TABLE IF EXISTS okato_simple_status;
CREATE TABLE okato_simple_status (
    "full" character varying(150) NOT NULL,
    simple character varying(50),
   CONSTRAINT okato_simple_status_pk PRIMARY KEY ("full")
);



--@: log data: okato_simple_status 

INSERT INTO okato_simple_status VALUES ('город',                   'город');
INSERT INTO okato_simple_status VALUES ('дачный поселковый совет', 'поселок');
INSERT INTO okato_simple_status VALUES ('деревня',                 'деревня');
INSERT INTO okato_simple_status VALUES ('курортный поселок',       'поселок');
INSERT INTO okato_simple_status VALUES ('населенный пункт',        'нп');
INSERT INTO okato_simple_status VALUES ('поселок городского типа', 'пгт');
INSERT INTO okato_simple_status VALUES ('поселок при станции',     'поселок');
INSERT INTO okato_simple_status VALUES ('поселок сельского типа',  'поселок');
INSERT INTO okato_simple_status VALUES ('разъезд',                 'разъезд');
INSERT INTO okato_simple_status VALUES ('село',                    'село');
INSERT INTO okato_simple_status VALUES ('слобода',                 'слобода');
INSERT INTO okato_simple_status VALUES ('станица',                 'станица');
INSERT INTO okato_simple_status VALUES ('станция',                 'станция');
INSERT INTO okato_simple_status VALUES ('хутор',                   'хутор');
INSERT INTO okato_simple_status VALUES ('железнодорожная станция', 'нп');


$MD_INIT$ */

--@: log settlement okato
--@: level +

DROP VIEW IF EXISTS q_match;
DROP TABLE IF EXISTS tmp_obj_term, tmp_dict_term ;

--@: log temp tables
CREATE TEMP TABLE tmp_obj_term (
  id bigint,
  field character(1),
  val text,
  scope bigint,
  scope_4 bigint
);

CREATE INDEX tmp_obj_term_field ON tmp_obj_term (field);
CREATE INDEX tmp_obj_term_scope_4 ON tmp_obj_term (scope_4);

CREATE TEMP TABLE tmp_dict_term (
  id bigint,
  field character(1),
  val text,
  scope bigint,
  scope_4 bigint
);

CREATE INDEX tmp_dict_term_field ON tmp_dict_term (field);
CREATE INDEX tmp_dict_term_scope_4 ON tmp_dict_term (scope_4);



--@: log building obj terms

INSERT INTO tmp_obj_term
  -- okato:user
  SELECT s.id, 'H'::char, s.okato_user, s.parent_boundary_oktmo
  FROM settlement s
  WHERE s.okato_user IS NOT NULL

  UNION

  -- отмеченные центры границ
  SELECT s.id, 'O'::char, b.oktmo, s.parent_boundary_oktmo
  FROM settlement s INNER JOIN boundary b ON s.parent_boundary_oktmo = b.id
  WHERE s.point_osm_id = b.capital_point_osm_id

  UNION 

  -- класс mjr|mnr
  SELECT s.id, 'C'::char,
    CASE 
      WHEN s.place IN ('city', 'town') THEN 'mjr'::text 
      ELSE 'mnr'::text
    END,
    s.parent_boundary_oktmo
  FROM settlement s

  UNION 
  
  -- наименование
  SELECT s.id, 'N'::char,
    unnest((yav_name_variants(string_to_array(s.name_all, ';'), NULL)).name),
    s.parent_boundary_oktmo
  FROM settlement s

  UNION 

  -- статусная часть
  SELECT s.id, 'S'::char,
    unnest((yav_name_variants(string_to_array(s.name_all, ';'), NULL)).status),
    s.parent_boundary_oktmo
  FROM settlement s

  UNION 

  -- admin_level для точек НП
  SELECT s.id, 'A'::char, unnest(s.admin_levels), s.parent_boundary_oktmo
  FROM settlement s;

--@: log building dict terms
INSERT INTO tmp_dict_term
  
  -- okato:user
  SELECT o.id, 'H'::char, o.code
  FROM okato o

  UNION

  -- административные центры в явном виде
  SELECT okato.id, 'O'::char, oktmo.code
  FROM okato INNER JOIN oktmo ON oktmo.capital_id = okato.id

  UNION

  SELECT o.id, 'N'::char, yav_normal_text(o.name)
  FROM okato o

  UNION

  SELECT o.id, 'S'::char, COALESCE(simple_status.simple, o.status)
  FROM okato o LEFT JOIN okato_simple_status simple_status ON simple_status.full = o.status

  UNION

  SELECT o.id, 'C'::char, CASE WHEN length(o.code) = 8 THEN 'mjr' ELSE 'mnr' END
  FROM okato o

  UNION 

  SELECT o.id, 'A'::char, '6'
  FROM okato o INNER JOIN oktmo ON oktmo.cls IN ('го', 'мр') AND oktmo.capital_id = o.id

  UNION 

  SELECT o.id, 'A'::char, '8'
  FROM okato o INNER JOIN oktmo ON oktmo.cls IN ('сп', 'гп') AND oktmo.capital_id = o.id;


UPDATE tmp_dict_term SET scope = t.scope
FROM (
  WITH RECURSIVE oktmo_root(scope, oktmo_code, lvl, tmp) AS (
    SELECT boundary.id, boundary.oktmo::text, 1, boundary.name::text
    FROM boundary WHERE oktmo IS NOT NULL

    UNION 

    SELECT oktmo_root.scope, oktmo.code::text, oktmo_root.lvl + 1, oktmo.raw
    FROM oktmo_root 
      LEFT JOIN oktmo ON oktmo.parent_obj = oktmo_root.oktmo_code
      LEFT JOIN boundary b ON b.oktmo = oktmo.code
    WHERE oktmo.id IS NOT NULL AND b.id IS NULL
  )
  SELECT okato.id, oktmo_root.scope
  FROM oktmo_root
    LEFT JOIN oktmo_okato oo ON oo.oktmo = oktmo_root.oktmo_code AND oo.is_in
    LEFT JOIN okato ON okato.code = oo.okato AND okato.is_settlement
    LEFT JOIN okato_simple_status simple_status ON simple_status.full = okato.status
  WHERE okato.id IS NOT NULL
) t WHERE t.id = tmp_dict_term.id;

DELETE FROM tmp_dict_term WHERE scope IS NULL;

/* INSERT INTO tmp_dict_term
WITH RECURSIVE oktmo_root(scope, oktmo_code, lvl, tmp) AS (
  SELECT boundary.id, boundary.oktmo::text, 1, boundary.name::text
  FROM boundary WHERE oktmo IS NOT NULL

  UNION 

  SELECT oktmo_root.scope, oktmo.code::text, oktmo_root.lvl + 1, oktmo.raw
  FROM oktmo_root 
    LEFT JOIN oktmo ON oktmo.parent_obj = oktmo_root.oktmo_code
    LEFT JOIN boundary b ON b.oktmo = oktmo.code
  WHERE oktmo.id IS NOT NULL AND b.id IS NULL
)
SELECT (yav_okato_settlement_cmp_record((okato.*))).*, oktmo_root.scope, NULL
FROM oktmo_root
  LEFT JOIN oktmo_okato oo ON oo.oktmo = oktmo_root.oktmo_code AND oo.is_in
  LEFT JOIN okato ON okato.code = oo.okato AND okato.is_settlement
	LEFT JOIN okato_simple_status simple_status ON simple_status.full = okato.status
WHERE okato.id IS NOT NULL; */

--@: log temp tables and functions
DROP TABLE IF EXISTS tmp_work, tmp_out, tmp_multiple;
CREATE TEMP TABLE tmp_work (
  obj_id bigint,
  dict_id bigint,
  m varchar(10)
);
CREATE INDEX tmp_work_obj_id ON tmp_work (obj_id);
CREATE INDEX tmp_work_dict_id ON tmp_work (dict_id);

CREATE TEMP TABLE tmp_out (
  obj_id bigint,
  dict_id bigint,
  m varchar(10)
);
CREATE INDEX tmp_out_obj_id ON tmp_out (obj_id);
CREATE INDEX tmp_out_dict_id ON tmp_out (dict_id);

CREATE TEMP TABLE tmp_multiple (
  obj_id bigint,
  dict_id bigint,
  m varchar(10)
);

DROP FUNCTION IF EXISTS yav_term_cross();
CREATE OR REPLACE FUNCTION yav_term_cross() RETURNS text AS
$BODY$
BEGIN
  EXECUTE '
  TRUNCATE tmp_work;

  INSERT INTO tmp_work
  SELECT q_match.* FROM q_match;

  -- убираем то что уже нашлось ранее
  DELETE FROM tmp_work
  WHERE EXISTS(SELECT * FROM tmp_out c WHERE tmp_work.obj_id = c.obj_id OR tmp_work.dict_id = c.dict_id);

  INSERT INTO tmp_out
  WITH m_o (obj_id) AS (        -- отбираем только с однозначными соответствиями
    SELECT obj_id FROM tmp_work
    GROUP BY obj_id 
    HAVING COUNT(dict_id)=1
  ),
  m_d (dict_id) AS (            -- отбираем только с однозначными соответствиями
    SELECT dict_id FROM tmp_work
    GROUP BY dict_id
    HAVING COUNT(obj_id)=1
  )
  SELECT tw.* FROM tmp_work tw
  INNER JOIN m_d ON tw.dict_id = m_d.dict_id
  INNER JOIN m_o ON tw.obj_id = m_o.obj_id;

  INSERT INTO tmp_multiple
  WITH m_o (obj_id) AS (        -- отбираем только с НЕ однозначными соответствиями
    SELECT obj_id FROM tmp_work
    GROUP BY obj_id 
    HAVING COUNT(dict_id) > 1
  ),
  m_d (dict_id) AS (            -- отбираем только с НЕ однозначными соответствиями
    SELECT dict_id FROM tmp_work
    GROUP BY dict_id
    HAVING COUNT(obj_id) > 1
  )
  SELECT tw.* FROM tmp_work tw
  LEFT JOIN m_d ON tw.dict_id = m_d.dict_id
  LEFT JOIN m_o ON tw.obj_id = m_o.obj_id
  WHERE m_o.obj_id IS NOT NULL OR m_d.dict_id IS NOT NULL; 
  ';
  RETURN 'yav_term_cross - done';
END;
$BODY$
LANGUAGE plpgsql VOLATILE;

--@: log M-H
CREATE OR REPLACE TEMP VIEW q_match AS 
  SELECT ot_n.id AS obj_id, dt_n.id AS dict_id, 'M-H'::text AS m
  FROM tmp_obj_term ot_n, tmp_dict_term dt_n
  WHERE ot_n.scope = dt_n.scope AND ot_n.field = 'H' AND dt_n.field = 'H' AND ot_n.val = dt_n.val;
SELECT yav_term_cross();

--@: log M-O
CREATE OR REPLACE TEMP VIEW q_match AS 
  SELECT ot_n.id AS obj_id, dt_n.id AS dict_id, 'M-O'::text AS m
  FROM tmp_obj_term ot_n, tmp_dict_term dt_n
  WHERE ot_n.scope = dt_n.scope AND ot_n.field = 'O' AND dt_n.field = 'O' AND ot_n.val = dt_n.val;
SELECT yav_term_cross();

--@: log M-A
CREATE OR REPLACE TEMP VIEW q_match AS
  SELECT ot_n.id AS obj_id, dt_n.id AS dict_id, 'M-A'::text AS m
  FROM tmp_obj_term ot_n, tmp_dict_term dt_n, tmp_obj_term ot_s, tmp_dict_term dt_s
  WHERE ot_n.scope = dt_n.scope AND ot_n.field = 'N' AND dt_n.field = 'N' AND ot_n.val = dt_n.val
    AND ot_s.id = ot_n.id AND dt_s.id = dt_n.id AND ot_s.field = 'A' AND dt_s.field = 'A'
    AND ot_s.val = dt_s.val;
SELECT yav_term_cross();


--@: log M-S
CREATE OR REPLACE TEMP VIEW q_match AS
  SELECT ot_n.id AS obj_id, dt_n.id AS dict_id, 'M-S'::text AS m
  FROM tmp_obj_term ot_n, tmp_dict_term dt_n, tmp_obj_term ot_s, tmp_dict_term dt_s
  WHERE ot_n.scope = dt_n.scope AND ot_n.field = 'N' AND dt_n.field = 'N' AND ot_n.val = dt_n.val
    AND ot_s.id = ot_n.id AND dt_s.id = dt_n.id AND ot_s.field = 'S' AND dt_s.field = 'S'
    AND ot_s.val = dt_s.val;
SELECT yav_term_cross();


--@: log M-C
CREATE OR REPLACE TEMP VIEW q_match AS
  SELECT ot_n.id AS obj_id, dt_n.id AS dict_id, 'M-C'::text AS m
  FROM tmp_obj_term ot_n, tmp_dict_term dt_n, tmp_obj_term ot_s, tmp_dict_term dt_s
  WHERE ot_n.scope = dt_n.scope AND ot_n.field = 'N' AND dt_n.field = 'N' AND ot_n.val = dt_n.val
    AND ot_s.id = ot_n.id AND dt_s.id = dt_n.id AND ot_s.field = 'C' AND dt_s.field = 'C'
    AND ot_s.val = dt_s.val;
SELECT yav_term_cross();

--@: log M-N
CREATE OR REPLACE TEMP VIEW q_match AS 
  SELECT ot_n.id AS obj_id, dt_n.id AS dict_id, 'M-N'::text AS m
  FROM tmp_obj_term ot_n, tmp_dict_term dt_n
  WHERE ot_n.scope = dt_n.scope AND ot_n.field = 'N' AND dt_n.field = 'N' AND ot_n.val = dt_n.val;
SELECT yav_term_cross();


--@: log attach boundary with admin_level=4
UPDATE tmp_obj_term
SET scope_4 = t.scope_4
FROM (
  SELECT DISTINCT t.scope, b.id AS scope_4
  FROM tmp_obj_term t INNER JOIN boundary_is_in is_in ON is_in.child = t.scope
    INNER JOIN boundary b ON b.id = is_in.parent AND b.admin_level = 4 

  UNION 

  SELECT DISTINCT t.scope, t.scope AS scope_4
  FROM tmp_obj_term t INNER JOIN boundary b ON t.scope = b.id AND b.admin_level = 4
) t
WHERE t.scope = tmp_obj_term.scope;

UPDATE tmp_dict_term
SET scope_4 = t.scope_4
FROM (
  SELECT DISTINCT t.scope, b.id AS scope_4
  FROM tmp_dict_term t INNER JOIN boundary_is_in is_in ON is_in.child = t.scope
    INNER JOIN boundary b ON b.id = is_in.parent AND b.admin_level = 4 

  UNION 

  SELECT DISTINCT t.scope, t.scope AS scope_4
  FROM tmp_dict_term t INNER JOIN boundary b ON t.scope = b.id AND b.admin_level = 4

) t
WHERE t.scope = tmp_dict_term.scope;

--@: log 4-H
CREATE OR REPLACE TEMP VIEW q_match AS 
  SELECT ot_n.id AS obj_id, dt_n.id AS dict_id, '4-H'::text AS m
  FROM tmp_obj_term ot_n, tmp_dict_term dt_n
  WHERE ot_n.scope_4 = dt_n.scope_4 AND ot_n.field = 'H' AND dt_n.field = 'H' AND ot_n.val = dt_n.val;
SELECT yav_term_cross();

--@: log 4-S
CREATE OR REPLACE TEMP VIEW q_match AS
  SELECT ot_n.id AS obj_id, dt_n.id AS dict_id, '4-S'::text AS m
  FROM tmp_obj_term ot_n, tmp_dict_term dt_n, tmp_obj_term ot_s, tmp_dict_term dt_s
  WHERE ot_n.scope_4 = dt_n.scope_4 AND ot_n.field = 'N' AND dt_n.field = 'N' AND ot_n.val = dt_n.val
    AND ot_s.id = ot_n.id AND dt_s.id = dt_n.id AND ot_s.field = 'S' AND dt_s.field = 'S'
    AND ot_s.val = dt_s.val;
SELECT yav_term_cross();

--@: log 4-A
CREATE OR REPLACE TEMP VIEW q_match AS
  SELECT ot_n.id AS obj_id, dt_n.id AS dict_id, '4-A'::text AS m
  FROM tmp_obj_term ot_n, tmp_dict_term dt_n, tmp_obj_term ot_s, tmp_dict_term dt_s
  WHERE ot_n.scope_4 = dt_n.scope_4 AND ot_n.field = 'N' AND dt_n.field = 'N' AND ot_n.val = dt_n.val
    AND ot_s.id = ot_n.id AND dt_s.id = dt_n.id AND ot_s.field = 'A' AND dt_s.field = 'A'
    AND ot_s.val = dt_s.val;
SELECT yav_term_cross();

/* --@: log 4-C
CREATE OR REPLACE TEMP VIEW q_match AS
  SELECT ot_n.id AS obj_id, dt_n.id AS dict_id, '4-C'::text AS m
  FROM tmp_obj_term ot_n, tmp_dict_term dt_n, tmp_obj_term ot_s, tmp_dict_term dt_s
  WHERE ot_n.scope_4 = dt_n.scope_4 AND ot_n.field = 'N' AND dt_n.field = 'N' AND ot_n.val = dt_n.val
    AND ot_s.id = ot_n.id AND dt_s.id = dt_n.id AND ot_s.field = 'C' AND dt_s.field = 'C'
    AND ot_s.val = dt_s.val;
SELECT yav_term_cross(); */

--@: log 4-N
CREATE OR REPLACE TEMP VIEW q_match AS 
  SELECT ot_n.id AS obj_id, dt_n.id AS dict_id, '4-N'::text AS m
  FROM tmp_obj_term ot_n, tmp_dict_term dt_n
  WHERE ot_n.scope_4 = dt_n.scope_4 AND ot_n.field = 'N' AND dt_n.field = 'N' AND ot_n.val = dt_n.val;
SELECT yav_term_cross();

--@: log build output
TRUNCATE settlement_okato_match;
INSERT INTO settlement_okato_match
SELECT * FROM tmp_out;

TRUNCATE settlement_okato_multiple;
INSERT INTO settlement_okato_multiple
SELECT * FROM tmp_multiple;

TRUNCATE settlement_okato_obj;
INSERT INTO settlement_okato_obj
SELECT DISTINCT id, EXISTS(SELECT * FROM tmp_out WHERE obj_id = tmp_obj_term.id) FROM tmp_obj_term;

TRUNCATE settlement_okato_dict;
INSERT INTO settlement_okato_dict
SELECT DISTINCT id, EXISTS(SELECT * FROM tmp_out WHERE dict_id = tmp_dict_term.id) FROM tmp_dict_term;

--@: level -