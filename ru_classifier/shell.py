#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import getopt

import sys
reload(sys)
sys.setdefaultencoding("utf-8")

DB_URL = 'postgresql+psycopg2://postgres@localhost/yav'
FETCH_SOURCE = 'mosclassific'
MODULE_NAME = 'oktmo'

engine = None
def get_engine():
  global engine
  from sqlalchemy import create_engine
  if not engine:
    engine = create_engine(DB_URL)
  return engine

session = None
def get_session():
  global session
  from sqlalchemy.orm import sessionmaker
  if not session:
    Session = sessionmaker(bind=get_engine())
    session = Session()
  return session

def action_fetch():
  global fmodule
  fmodule.fetch()

def action_create():
  global cmodule
  cmodule.metadata.create_all(get_engine())

def action_load():
  for t in cmodule.metadata.tables:
    get_session().execute('TRUNCATE %s' % t)
  def lookup(obj_class, f):
    try:
      return get_session().query(obj_class).filter(f).all()[0]
    except IndexError:
      return None
  for obj in cmodule.reader(load_file, lookup):
    get_session().add(obj)
    pass

def action_drop():
  global cmodule
  cmodule.metadata.drop_all(get_engine())
  pass

if __name__ == '__main__':
  jobs = []
  opts, args = getopt.getopt(sys.argv[1:], '', [
          'fetch',              # скачать
          'create',             # создать схему
          'load',               # загрузить из файла в бд
          'drop',               # удалить схему

          'source=',            # источник загрузки
          'from=',              # файл для загрузки в бд
          'db='])               # dburl для sqlalchemy

  if len(args) <> 1:
    pass
  else:
    MODULE_NAME = args[0]
    global cmodule
    cmodule = __import__(MODULE_NAME)

  load_file = sys.stdin

  for k,v in opts:
    if k == '--drop':
      jobs.append(action_drop)
    elif k == '--create':
      jobs.append(action_create)
    elif k == '--fetch':
      jobs.append(action_fetch)
    elif k == '--load':
      jobs.append(action_load)
    elif k == '--db':
      DB_URL = v
    elif k == '--source':
      FETCH_SOURCE = v
      __import__('.'.join((MODULE_NAME, FETCH_SOURCE)) )
      fmodule = getattr(cmodule, FETCH_SOURCE)
    elif k == '--from':
      load_file = open(v, 'r')

  for job in jobs:
    job()

  if session:
    session.commit()




