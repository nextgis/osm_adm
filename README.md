Границы административно-территориального деления РФ из OpenStreetMap
====================================================================

Данные по АТД РФ в shape-формате из проекта OSM с атрибутикой из классификаторов

Установка:
* создание БД yav:
```
  CREATE ROLE yav WITH LOGIN;
  CREATE DATABASE yav WITH OWNER=yav;
  # В БД yav от админа выполнить:
  CREATE EXTENSION postgis;
```
* установить зависимости:
    osm2pgsql
    в virtualenv поставить:
        sqlparse
        psycopg2


Текущее состояние проекта:

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
