CREATE TABLE IF NOT EXISTS oktmo_to_okato (
    grp character varying(10) NOT NULL,
    oktmo character varying(8) NOT NULL,
    okato character varying(11),
    m integer
);

TRUNCATE oktmo_to_okato;

-- временные таблицы, куда собираем все для сопоставления
DROP TABLE IF EXISTS tmp_o2o_okato;
CREATE TEMP TABLE tmp_o2o_okato (
  grp VARCHAR(10),
  okato VARCHAR(11)
);

DROP TABLE IF EXISTS tmp_o2o_oktmo;
CREATE TEMP TABLE tmp_o2o_oktmo (
  grp VARCHAR(10),
  oktmo VARCHAR(8)
);

INSERT INTO tmp_o2o_okato (grp, okato)
    -- субъекты
    SELECT 'subject', code FROM okato
    WHERE is_subject
  UNION
    -- районы и города областного значения
    SELECT 'district', code FROM okato
    WHERE lvl = 2 AND not is_subject;

INSERT INTO tmp_o2o_oktmo (grp, oktmo)
    SELECT 'subject', code FROM oktmo
    WHERE is_subject
  UNION
    -- городские округа и муниципальные районы
    SELECT 'district', code FROM oktmo
    WHERE cls IN ('го', 'мр');


INSERT INTO oktmo_to_okato
WITH oktmo_to_okato (grp, oktmo, okato) AS (
  WITH
    okato_top (grp, okato_root, okato_child)AS (
      -- grp         : группа для сравнения
      -- okato_root  : код верхнего уровня, на котором ищется соответствие
      -- okato_child : дочерний элемент
      WITH RECURSIVE okato_tree(grp, root, child) AS (
          SELECT grp, okato, okato
          FROM tmp_o2o_okato
        UNION
          SELECT top.grp, top.root, okato.code
          FROM okato_tree top
            LEFT JOIN okato ON parent = top.child
            LEFT JOIN tmp_o2o_okato ON tmp_o2o_okato.okato = okato.code AND top.grp = tmp_o2o_okato.grp
          WHERE okato.code IS NOT NULL
            -- отсекаем, чтобы не включать одну и туже иерархию дважды
            AND tmp_o2o_okato.okato IS NULL
      )
      SELECT grp, okato_tree.root, okato_tree.child
      FROM okato_tree
        LEFT JOIN okato ON okato_tree.child = okato.code
  ),
  oktmo_settlement (grp, oktmo_code, okato_code) AS (
    -- grp          :
    -- oktmo_code   :
    -- okato_code   :
    WITH
      RECURSIVE child_search(grp, root,  child) AS (
          SELECT tmp_o2o_oktmo.grp AS grp, code AS root, code AS child
          FROM oktmo
            LEFT JOIN  tmp_o2o_oktmo ON tmp_o2o_oktmo.oktmo = oktmo.code
          WHERE
            tmp_o2o_oktmo.grp IS NOT NULL
        UNION
          SELECT top.grp, top.root, t.code
          FROM child_search top LEFT JOIN oktmo t ON t.parent = top.child
            LEFT JOIN tmp_o2o_oktmo ON tmp_o2o_oktmo.oktmo = t.code AND top.grp = tmp_o2o_oktmo.grp
          WHERE tmp_o2o_oktmo.grp IS NULL
      )
    SELECT grp AS grp, root, oktmo_okato.okato
    FROM child_search
      LEFT JOIN oktmo_okato ON child_search.child = oktmo_okato.oktmo
  )
  SELECT oktmo_settlement.grp AS grp,
         oktmo_code AS oktmo,
         okato_root AS okato,
         COUNT(DISTINCT okato_child) AS m

  FROM oktmo_settlement
    LEFT JOIN okato_top ON oktmo_settlement.grp = okato_top.grp AND oktmo_settlement.okato_code = okato_top.okato_child
  GROUP BY oktmo_settlement.grp, oktmo_code, okato_root
)
SELECT t.grp, t.oktmo, MIN(t.okato) AS okato, MAX(t.m) AS m
FROM (SELECT grp, oktmo, okato, MAX(m) AS m FROM oktmo_to_okato GROUP BY grp, oktmo, okato) m
  LEFT JOIN oktmo_to_okato t ON m.grp = t.grp AND m.oktmo = t.oktmo AND m.okato = t.okato AND m.m = t.m
WHERE t.grp IS NOT NULL
GROUP BY t.grp, t.oktmo;

SELECT * FROM tmp_o2o_oktmo WHERE grp ='subject';

SELECT grp, oktmo.code AS oktmo, oktmo.raw, okato.code AS okato, okato.raw, m
FROM oktmo_to_okato o2o
  LEFT JOIN oktmo ON oktmo.code = o2o.oktmo
  LEFT JOIN okato ON okato.code = o2o.okato
WHERE grp='subject'
ORDER BY oktmo.code;


