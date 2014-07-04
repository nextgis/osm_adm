Границы административно-территориального деления РФ из OpenStreetMap
====================================================================

Данные по АТД РФ в shape-формате из проекта OSM с атрибутикой из классификаторов

Установка:
----------
* создание БД yav:
```sql
  CREATE ROLE yav WITH LOGIN;
  CREATE DATABASE yav WITH OWNER=yav;
```

В БД yav от админа выполнить:
```sql
  CREATE EXTENSION postgis;
```
* установить зависимости:
  * osm2pgsql
  * virtualenv (```sudo pip install virtualenv```), в нём поставить:
    * sqlparse
    * psycopg2
    * sqlalchemy
        
* импортировать классификаторы окато и октмо, для этого:
 * Вероятно (структура создаваемых таблиц получается другая, чем требуется в последствии в скриптах yav-ru/*-*.sql) нужно установить clscol и clscol-data: https://github.com/dezhin/clscol, https://github.com/dezhin/clscol-data и импортировать данные классификаторов в БД согласно инструкции.
```
        # (
        #   загрузка классификатора командой:
        #   env/bin/clscol import --db postgresql://yav@localhost/yav okato  clscol-data/okato/okato-154.yaml
        #   env/bin/clscol import --db postgresql://yav@localhost/yav oktmo  clscol-data/oktmo/oktmo-079.yaml
        # )
        # Скорее всего эти данные нужны для скриптов ru_classifier/shell
``` 
 * Создать таблицы okato и oktmo при помощи скриптов ru_classifier/shell:
```
        ./shell.py --create --load --from data/okato okato
        ./shell.py --create --load --from data/oktmo oktmo
        (
            shell работает от администратора и создает таблицы okato и oktmo недоступные для пользователя yav. Нужно выяснить, зачем shell права админа. Пока же передаю руками таблицы пользователю yav:
            ALTER TABLE okato OWNER TO yav;
            ALTER TABLE oktmo OWNER TO yav;
            ALTER TABLE oktmo_okato OWNER TO yav;
        )
```
 * Создать и заполнить таблицу okato_to_oktmo данными:
```
        python yav-sql-run --cfg yav.cfg --run ru_classifier/oktmo_to_okato/oktmo_to_okato.sql
```

* Настройка прав: 90-bounary-error.sql хочет права на чтение таблицы spatial_ref_sys, принадлежащей админу. Пока делаю по-тупому:
```
        ALTER TABLE spatial_ref_sys OWNER TO yav;
```

* Инициализировать БД, записав в нее необходимые sql-функции:
```
        python yav-sql-run --cfg yav.cfg --run --action MD_INIT yav-ru/??-*.sql
```


Текущее состояние проекта:
---------------------------

* основная обработка происходит в daily-run скрипте, который вызвается через cron/anacron
* daily-run последовательно производит следующие действия:
```
    установка переменных окружения (PythonPath и др.):
    source /etc/profile
    source /home/osm_adm/.profile

    Загрузка через osm2pgsql файла дампа OSM (на сегодня файл не существует) в базу "host=localhost dbname=yav user=yav":
    yav-osm2pgsql/run

    Запуск на выполнение содержимого sql-файлов:
    ~/bin/python2.6 yav-sql-run --run --cfg yav.cfg yav-ru/*-*.sql
        00-functions.sql
        20-boundary.sql
        22-boundary-oktmo.sql
        25-boundary-oktmo-hierarchy.sql
        28-bounary-okato-geometry.sql
        40-settlements.sql
        41-settlement-oktmo.sql
        42-settlement-okato.sql
        43-settlement-kladr.sql
        44-settlement-gns.sql
        60-boundary-browser.sql
        70-settlement-browser.sql
        71-settlement-browser-multiple.sql
        72-boundary-browser-centroid.sql
        80-boundary-stat.sql
        90-bounary-error.sql

        Замечание:
            40-settlements.sql выдает предупреждение gserialized_gist_joinsel: jointype 1 not supported. Нужно разобраться, насколько это серьезно

    Запуск sql-файла:
    bin/python2.6 yav-sql-run --run --cfg yav.cfg yav-adm/*-*.sql
        00-prepeare.sql


    Экспорт таблиц постгрес в шейпы, расчет статистик по количеству импортированых объектов, экспорт данных в таблицу постгрес gen, архивация шейпов
    yav-adm/export

    Запуск sql-файла:
    bin/python2.6 yav-sql-run --run --cfg yav.cfg yav-dc/*-*.sql
        00-prepeare.sql

    Экспорт таблиц постгрес в шейпы, расчет статистик по количеству импортированых объектов
    yav-dc/export
```
