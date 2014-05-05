#!/usr/bin/env python
# -*- coding: utf-8 -*- 

from urllib2 import Request, urlopen, HTTPError
import re
from BeautifulSoup import BeautifulSoup

import sys
reload(sys)
sys.setdefaultencoding("utf-8")
from sys import stderr

import time

UA = 'Mozilla/5.0 (compatible; MSIE 5.5; Windows NT)'

def _fetch_page(url):
    print >> stderr, '[F] %s' % url
    # банят по User-Agent-у, поэтому добавим туда время
    req = Request(url, headers={ 'User-Agent' : UA + "(%d)" % time.time()})
    page = None
    while not page:
      try:
        page = urlopen(req)
        soup = BeautifulSoup(page)
      except HTTPError:
        print >> stderr, "[F]   - не получилось: ждем 5 минут"  
        time.sleep(300)  
    return soup

def fetch_level1():
  # загрузка кодов первого уровня (а-ля субъекты)
  # генератор ( code, raw ) 
  page = _fetch_page('http://www.mosclassific.ru/mClass/oktmo_view.php')
  for o in page.find('select', attrs={'name' : 'type'}).findAll('option'):
    yield (o.attrs[0][1], o.find(text=True))

def fetch_level2(level1):
  # элементы второго уровня  
  # генератор ( code, raw )  
  page = _fetch_page('http://www.mosclassific.ru/mClass/oktmo_view.php?type=%s' % level1)  
  for o in page.find('select', attrs={'name' : 'zone'}).findAll('option'):
    yield (level1 + o.attrs[0][1], o.find(text=True))

def fetch_list(level1, level2):
  # лимита в 64k должно хватить каждому
  # генератор ( code, raw )  
  page = _fetch_page('http://www.mosclassific.ru/mClass/oktmo_view.php?type=%s&zone=%s&filter=65535'
                      % (level1, level2))  
  for tr in page.findAll('tr'):
    # print tr                    
    tds = tr.findAll('td', text=True)
    if len(tds) <> 2:
      continue
    (code, raw) = tds
    if not code.startswith(level1 + level2):
      continue  
    yield (code, raw)

def fetch_detail(code):
  # детальные зaписи
  # генерирует (okato_code, settlement_name)
  settlement_names = []
  okato_codes = []
  page = _fetch_page('http://www.mosclassific.ru/mClass/oktmo_viewd.php?id=%s' % code)
  for tr in page.findAll('tr'):
    tds = tr.findAll('td')
    if len(tds) <> 2:
      continue
    if tds[0].text == "Наименование НП по законодательству:":
      settlement_names = tds[1].findAll(text=True)
    if tds[0].text == "Код ОКАТО населенного пункта:":
      okato_codes = tds[1].findAll(text=True)
  if len(settlement_names) == 0 or len(okato_codes) == 0:
    print >> stderr, '[W] %s - нет информации о населенных пунктах или кодах ОКАТО' % code
  if len(settlement_names) <> len(okato_codes):
    print >> stderr, '[W] %s - разное количество наименований и кодов НП' % code
    
    # чтобы не плодить ошибок выводим только коды ОКАТО
    for o in okato_codes:
      yield (o, )  

  else:
    for ind in range(0, len(okato_codes)):
      yield (okato_codes[ind], settlement_names[ind])  

def fill(v):
  while len(v) < 8:
    v = v + '0'
  return v

def _print(t, indent=0):
  l = list(t)
  l[0] = fill(l[0])
  print "\t".join(l)
  
def fetch():
  for l1 in fetch_level1():
    _print(l1)
    for ol in fetch_detail(fill(l1[0])):
      _print(ol)  
    print ''
    for l2 in fetch_level2(l1[0]):
      _print(l2)
      for ol in fetch_detail(fill(l2[0])):
        _print(ol)  
      print ''
      for i in fetch_list(l1[0], l2[0][-1]):
          _print(i)
          if not i[0].endswith('00') or i[0].endswith('000'):
            # с двумя последними нулями - группировочные позиции, в них нет НП  
            for okato_link in fetch_detail(i[0]):
              _print(okato_link)
            # time.sleep(0.5)
          # пустая строка - конец ОКАТО кодов
          print '';

  
