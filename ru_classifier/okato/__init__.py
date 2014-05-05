# -*- coding: utf-8 -*-
from sqlalchemy import Column as C, Unicode, ForeignKey, SmallInteger, Boolean, Enum
from sqlalchemy.ext.declarative import declarative_base

import re
from sys import stderr
# коды автономных округов, которые до сих пор являются субъектами, закодированные на втором уровне
SUBJ_AD = (
    '11100000', # Ненецкий
    '71100000', # Ханты-Мансийский
    '71140000', # Ямало-Ненецкий
)

# статусные части
STATUS_SEARCH = (
 (ur'^г\s+(.*)',                       ur'город'),
 (ur'^пгт\s+(.*)',                     ur'поселок городского типа'),
 (ur'^рп\s+(.*)',                      ur'рабочий поселок'),
 (ur'^кп\s+(.*)',                      ur'курортный поселок'),
 (ur'^к\s+(.*)',                       ur'кишлак'),
 (ur'^пс\s+(.*)',                      ur'поселковый совет'),
 (ur'^смн\s(.*)',                      ur'cомон'),
 (ur'^д\s+(.*)',                       ur'деревня'),
 (ur'^с\s+(.*)',                       ur'село'),
 (ur'^вл\s+(.*)',                      ur'волость'),
 (ur'^дп\s+(.*)',                      ur'дачный поселковый совет'),
 (ur'^п\s+(.*)',                       ur'поселок сельского типа'),
 (ur'^нп\s+(.*)',                      ur'населенный пункт'),
 (ur'^сл\s+(.*)',                      ur'слобода'),
 (ur'^ст\s+(.*)',                      ur'станция'),
 (ur'^нп\s+(.*)',                      ur'населенный пункт'),
 (ur'^п\.ст\s+(.*)',                   ur'поселок при станции'),
 (ur'^жд_ст\s+(.*)',                   ur'железнодорожная станция'),
 (ur'^ж/д ст\s+(.*)',                  ur'железнодорожная станция'),
 (ur'^ж/д рзд\s+(.*)',                 ur'железнодорожный разъезд'),
 (ur'^м\s+(.*)',                       ur'местечко'),
 (ur'^х\s+(.*)',                       ur'хутор'),
 (ur'^сл\s+(.*)',                      ur'слобода'),
 (ur'^ст\-ца\s+(.*)',                  ur'станица'),
 (ur'^у\s+(.*)',                       ur'улус'),
 (ur'^рзд\s+(.*)',                     ur'разъезд'),
 (ur'^клх\s+(.*)',                     ur'колхоз'),
 (ur'^жд\s+(.*)',                      ur'железнодорожная станция'),
 (ur'^свх\s+(.*)',                     ur'совхоз'),
 (ur'^зим\s+(.*)',                     ur'зимовье'),
 (ur'^аул\s+(.*)',                     ur'аул'),
 (ur'^починок\s+(.*)',                 ur'починок'),
 (ur'^казарма\s+(.*)',                 ur'казарма'),
 (ur'^выселок\s+(.*)',                 ur'выселок'),
 (ur'^аал\s+(.*)',                     ur'аал'),
 (ur'^метеостанция\s+(.*)',            ur'метеостанция'),
 (ur'^кордон\s+(.*)',                  ur'кордон'),
 (ur'^монтерский\sпост\s+(.*)',        ur'монтерский пост'),
 (ur'^гидрологический\sпост\s+(.*)',   ur'гидрологический пост'),
 (ur'^дорожный рзд\s+(.*)',            ur'дорожный разъезд'),
 (ur'^маяк\s+(.*)',                    ur'маяк'),
 (ur'^заимка\s+(.*)',                  ur'заимка'),
)

# компилируем regexp-ы для статусов НП
_STATUS_SEARCH = []
for itm in STATUS_SEARCH:
  n = (re.compile(itm[0], re.UNICODE), itm[1:])
  _STATUS_SEARCH.append(n)
  
def fill(start, to_len=8):
  while len(start) < to_len:
    start = start + '0'
  return start  

Base = declarative_base()

class OkatoObj(Base):
  __tablename__ = 'okato'

  CLS_ENUM = (
    u'адм_район',                # районы субъекта
    u'город',                    # города
    u'пгт',                      # поселки городского типа
    u'город|пгт',
    u'гфз_1',                    # первый уровень деления ГФЗ: округа Москвы, районы Спб
    u'гфз_2',                    # второй уровень деления ГФЗ: районы Москвы, округа Спб
    u'нп',
    u'сельсовет',
    u'unknown',
    u'гор_район'                 # район города, или городского округа
  )
  
  code = C(Unicode(11), primary_key=True) # код ОКАТО
  raw  = C(Unicode(255))                  # строка из ОКАТО as-is

  is_group = C(Boolean())       # это группировка ?
  parent = C(Unicode(11))       # родитель с учетом группировок
  parent_obj = C(Unicode(11))   # родитель без учета группировок
  
  lvl  = C(SmallInteger())      # уровень
  cls  = C(Unicode(10))         # класс

  is_settlement = C(Boolean())  # это населенный пункт 
  is_subject = C(Boolean())     # это субъект
  name = C(Unicode(100))        # имя без статусной части
  status = C(Unicode(100))      # статусная часть

  cl_class = None
  cl_level = None
  manager = None

  def parse(self, lookup=None):
    code = self.code
    raw  = self.raw
    self.manager = None

    # код заканчивается на n нулей
    zeroes = lambda n: self.code.endswith('0' * n)
      
    # все группировки заканчиваются на '/'
    self.is_group = raw[-1] == '/'

    p1 = int(code[2])    # признак 1 - разряд 3
    p2 = int(code[5])    # признак 2 - разряд 6
    v1 = int(code[3:5])  # разряды 4-5
    v2 = int(code[6:8])  # разряды 7-8

    level = None

    if self.is_group:
      if len(code) == 8:
        if zeroes(5):
          self.parent = fill(code[:2])
        elif zeroes(4):
          pst = int(code[3])
          while True:
            p = fill(code[:3] + str(pst))
            print p
            po = lookup(OkatoObj, OkatoObj.code == p)
            if po:
              self.parent = po.code
              stderr.write( "[%s] %s > [%s] %s\n" %(self.code, self.raw, po.code, po.raw))
              break
            else:
              pst = pst - 1
              if pst < 0:
                stderr.write(u"Не удалось определить родителя для %s %s\n" % (self.code, self.raw))
                break
              
        elif code.endswith(('00', '50')):
          self.parent = code[:5] + '000'

      if len(code) == 11:
        assert code[-3:] == '000', 'Ошибка в группировке'  
        self.parent = fill(code[:8])
        self.parent_obj = fill(code[:8])

    elif len(code) == 8 and not self.is_group:
      if zeroes(6):
        self.cl_level = 1
        self.parent     = None
        self.parent_obj = None
      if zeroes(5):
        # это автономный округ
        self.cls = 'ао'
        self.parent = fill(code[:2])
        self.parent_obj = fill(code[:2])
      elif zeroes(3):
        self.cl_level = 2
        self.parent = code[:3] + '00000'
        self.parent_obj = code[:2] + '000000'
        if p1 == 1:
          pst = int(code[3])
          while True:
            p = fill(code[:3] + str(pst))
            po = lookup(OkatoObj, OkatoObj.code == p)
            if po and po.is_group:
              self.parent = po.code
              stderr.write( "[%s] %s > [%s] %s\n" %(self.code, self.raw, po.code, po.raw))
              break
            else:
              pst = pst - 1
              
        elif p1 == 2:
          self.parent_obj = code[:2] + '000000'
          if v1 in range(1, 60):
            self.cl_class = 'адм_район'
            self.parent     = code[:3] + '00000'
          elif v1 in range(60, 100):
            self.cl_class = 'гфз_1'
            self.parent     = code[:3] + '60000'

        elif p1 == 4:
          # по описанию статуc должен зависеть от v1,
          # но на московской области это не работает,
          # поэтому город или пгт
          
          # попробуем посмотреть группировку верхнего уровня
          p_code = code[:3] + '00000'
          parent_group = lookup(OkatoObj, OkatoObj.code == p_code.encode('utf-8'))
          pr = parent_group.raw
          
          if pr.startswith(u'Города'):
            self.cl_class = 'город'
          elif pr.startswith(u'Поселки городского типа'):
            self.cl_class = 'пгт'  
            
        elif p1 == 5:

          # это значения признака в классификаторе не описано,
          # на московской области вроде бы работает
          if   v1 in range(1, 60):
            self.cl_class = 'город'
          elif v1 in range(60, 100):
            self.cl_class = 'пгт'
            
      else:  
        self.cl_level = 3
        self.parent = code[:7] + '0'
        self.parent_obj = code[:5] + '000'
        if p2 == 3:
          self.cl_class = 'гор_район'
        elif p2 == 5:
          if v2 in range(1, 50):
              self.cl_class = 'город'
          elif v2 in range(50, 100):
            if v1 in range(60, 100):
              self.cl_class = 'гфз_2'  
            elif v1 in range(1, 60):   
              self.cl_class = 'пгт'
        elif p2 == 6:
          # в самарской области сюда попадают устраненные НП в Тольяти  
          self.cl_class = 'unknown'  
        elif p2 == 8:
          self.cl_class = 'сельсовет'  
    elif len(code) == 11 and not self.is_group:
      self.cl_level = 4
      self.cl_class = 'нп'
      self.parent = fill(code[:8], to_len=11)
      self.parent_obj = fill(code[:8])
    
    # на первом уровне все субъекты, на втором только то, что еще не успели упразднить
    self.is_subject = self.cl_level == 1 or (code in SUBJ_AD)

    self.is_district = len(code) == 8 and code[2] == '2' and code[-3:] == '000' and code[3:5] <> '00'
    self.is_city = len(code) == 8 and code[2] == '4' and code[-3:] == '000' and code[3:5] <> '00'

    if self.cl_class in ('город', 'пгт', 'город|пгт'):
        self.is_settlement = True
        if self.cl_class in ('город'):
          self.name = raw
          self.status = self.cl_class
        elif self.cl_class in ('пгт'):
          self.name = raw  
          self.status = "поселок городского типа"  
    if len(code) == 11 and not self.is_group:
      # сельские НП  
      self.is_settlement = True

    self.lvl = self.cl_level
    self.cls = self.cl_class
    
    # определяем статус
    for ss in _STATUS_SEARCH:
      m = ss[0].match(raw)
      if m:
        (self.name, self.status) = (m.group(1), ss[1])

    if self.is_settlement and not self.status:
      stderr.write(u"Не удалось определить статус НП %s [%s]\n" % (self.code, self.raw))

    if self.code in SUBJ_AD:
      self.parent = fill(self.code[:2])
    
    # if self.parent in SUBJ_AD:
    #    self.parent_obj = self.parent


       

metadata = Base.metadata

def reader(src, lookup=None):
  for l in src:
    i = l.decode('utf-8')[:-1]
    obj = OkatoObj()
    (code, raw) = i.split("\t")
    obj.code = code
    obj.raw = raw
    obj.parse(lookup=lookup)
    yield obj
