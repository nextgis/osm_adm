# -*- coding: utf-8 -*-
import urllib2
import re

import sys
reload(sys)
sys.setdefaultencoding("utf-8")

from sys import stderr
import time
from BeautifulSoup import BeautifulSoup

from __init__ import OkatoObject

USER_AGENT = 'Mozilla/4.0 (compatible; MSIE 5.5; Windows NT)'
URL        = 'http://www.mosclassific.ru/mClass/okato_view.php?sort=KOD&text=%s+&filter=%d&PAGEN_1=%d'

UA = 'Mozilla/5.0 (compatible; MSIE 5.5; Windows NT)'

def fetch_by_prefix(prefix='', limit=1000, sleep=5):
  page_num = 1
  def _fetch_page():
    url = URL % (prefix, limit, page_num)
    print >> stderr, 'fetching %s' % url
    req = urllib2.Request(url,
                        headers={ 'User-Agent' : USER_AGENT})
    page = urllib2.urlopen(req)
    soup = BeautifulSoup(page)
    return soup
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
    return page

  count = 0
  soup = _fetch_page()
  
  # определяем кол-во страниц
  try:
    total_count = int(re.search('\d+.+?\d+.+?(\d+)',
                              soup.find(**{"class" : "navtext"}).find(text=True)).group(1))
  except Exception:
    # если нет надписи о кол-ве страниц, значит все уместилось на первой  
    total_count = None

  while soup:
    for tr in soup.findAll('tr'):
      tds = tr.findAll(text=True)
      if len(tds) <> 2:
        # две колонки
        continue

      (code, raw) = tds
      code = code.replace(' ', '')

      if not re.match(r'\d{8}', code) and not re.match(r'\d{11}', code):
        # попалось что-то не то, все коды ОКАТО 8 или 11 цифр  
        continue

      if not code.startswith(prefix):
        # то же что-то не то, потому что не начинается с преффикса, который мы запрашивали
        continue

      count = count + 1
      yield (code, raw)

    print >> stderr, "страница %d: %d строк" % (page_num, count)

    if count < total_count:
      page_num = page_num + 1  
      time.sleep(sleep)
      soup = _fetch_page()
    else:
      soup = None  



def fetch():
  for base in range(1, 100):
    bp = '%02d' % base
    print >> stderr, "prefix : %s" % bp  
    for l in fetch_by_prefix(prefix=bp, sleep=0.1):
      print "\t".join(l)

