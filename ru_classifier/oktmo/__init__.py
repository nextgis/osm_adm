# -*- coding: utf-8 -*- 
from sqlalchemy import Column as C, Unicode, String, ForeignKey, SmallInteger, Boolean, Enum, Integer
from sqlalchemy.ext.declarative import declarative_base

import re
from sys import stderr

# Субъекты закодированные на 2-м уровне

SUBJ_AD = ( '118',        # Ненецкий АО
            '718',        # Ханты-Манскийский АО
            '719' )       # Ямало-Ненецкий АО
          

Base = declarative_base()


# обработка simple_name
SIMPLE_NAME_REs = (
  (('мр', ), (
               ( u'муниципальный\s+район', u'район'),
               ( u'Муниципальный\s+район\s+(.+ий)', ur'\1 район'),
               ( u'Город\s+.+\s+и\s+(.+\s+район)', ur'\1 район'),
               ( u'район и Город .+', u'район')
             )),
  (('сф', ), (
               ( u'Города Санкт-Петербурга', ur'Город Санкт-Петербург'),
	       ( u'Города Москвы', ur'Город Москва' ),
	       ( u'Республики Алтай' , ur'Республика Алтай'),
               ( u'Адыгеи', ur'Адыгея'),
               ( u'Республики Тывы', ur'Республика Тыва'),
               ( u'Татарстана', ur'Татарстан'),
	       ( u'Еврейской автономной области', ur'Еврейская автономная область'),
               ( u'Чукотского автономного округа',  ur'Чукотский автономный округ'),
               ( u'\s\-\sЧувашии', ur'(Чувашия)'),
               ( u'ского\s+края', ur'ский край'),
               ( u'ой\s+области', ur'ая область'),
               ( u'Республики\s+(.*)ии', ur'Республика \1ия'),
	       ( u'кой Республики', ur'ская Республика'),
	       ( u'Муниципальные образования ', ur''),
               ( u'\(города федерального значения\)', ur''),
               ( u'\(столицы Российской Федерации города федерального значения\)', ''),
	       ( u'Республики', ur'Республика')
              )),
)

def fill(v):
  while len(v) < 8:
    v = v + '0'
  return v

class OktmoObj(Base):
  __tablename__ = 'oktmo'

  CLS_ENUM = (
    u'сф',                      # субъект
    
    u'мр',                      # муниципальный район
    u'го',                      # городской округ
    
    u'гп',                      # городское поселение
    u'сп',                      # сельское поселение
    u'мс',                      # межселенная территория

    u'тгфз'                     # внутригородская территория города федерального значения
  )
  
  id         = C(Integer(), primary_key=True)
  code       = C(Unicode(8))                          # код ОКТМО
  raw        = C(Unicode(255))                        # строка из ОКТМО
  parent     = C(Unicode(8))                          # родитель с учетом группировки
  parent_obj = C(Unicode(8))                          # родетель без учета группировок
  is_group   = C(Boolean())                           # это группировка ?

  lvl        = C(SmallInteger())                      # уровень без учета группировок
  cls        = C(Enum(*CLS_ENUM, **{'native_enum':False}))  # класс

  is_subject = C(Boolean())                           # это субъект?
  simple_name = C(Unicode(255))                       # упрощенное название
  
  def parse(self, lookup=None):
    self.id = int(self.code)

    # убираем сноску с конца строки
    if self.raw[-1] == '*':
      self.raw = self.raw[:-1]
    
    # код заканчивается на n нулей
    zeroes = lambda n: self.code.endswith('0' * n)

    # первые n cимволов кода
    first = lambda n: self.code[:n]

    # дополненные нулями
    first_fill = lambda n: fill(self.code[:n])


    p1 = int(self.code[2])      # признак 1 - 3-й разряд
    p2 = int(self.code[5])      # признак 2 - 6-й разряд

    g1 = int(self.code[3:5])
    g2 = int(self.code[6:8])

    if self.raw[-1] == '/':
      self.is_group = True

      if zeroes(5):
        # субъекты закодированные на втором уровне
        if self.code[:3] in SUBJ_AD:
          self.is_group = False
          self.is_subject = True
          self.cls = 'сф'
        self.parent = first_fill(2)
      elif zeroes(4):
        # группировка МР и ГО внутри авт. округов
        self.parent = first_fill(3)
      elif zeroes(2):
        self.parent = first_fill(5)  
    else:
      self.is_group = False  

      if zeroes(6):
        self.lvl = 1
        self.is_subject = True
        self.cls = 'сф'

      elif zeroes(3):
        self.lvl = 2
        self.parent_obj = fill(first(2))
        if p1 == 8:
          if g1 in range(10, 50):
            self.cls = 'мр'
          elif g1 in range(50, 99):
            self.cls = 'го'
        elif p1 == 6:
          self.cls = 'мр'
        elif p1 == 7:
          self.cls = 'го'
        elif p1 == 3:
          self.cls = 'тгфз'
        elif p1 == 9:
          if lookup(OktmoObj, OktmoObj.code == fill(first(2) + '3')):
            self.cls = 'тгфз'
          elif g1 in range(11,50):
            self.cls = 'мр'
          elif g1 in range(50,100):
            self.cls = 'го'  
                
        if not self.cls:
          stderr.write(u'Неопознаный признак P1 %d в %s %s\n' % (p1, self.code, self.raw) )

      else:
        self.lvl = 3  
        if p2 == 1:
          self.cls = 'гп'
        elif p2 == 4:
          self.cls = 'сп'
        elif p2 == 7:
          self.cls = 'мс'  
          
        if not self.cls:
          stderr.write(u'Неопознаный признак P2 %d в %s %s\n' % (p2, self.code, self.raw))


      if self.lvl > 1 and not self.parent:
        self.parent = fill( self.code[ :{2: 3, 3: 6} [self.lvl]] )

    # parent_obj
    if self.parent:    
      op = lookup(OktmoObj, OktmoObj.code == self.parent)
      if not op:
        stderr.write(u'Неверный родитель для %s %s\n' % (self.code, self.raw) )
      elif not op.is_group:
        self.parent_obj = op.code
      elif op.is_group and op.parent_obj:
        self.parent_obj = op.parent_obj
      else:
        stderr.write(u"Двойная группировка: %s %s\n" % (self.code, self.raw))
        
    if not self.is_group:
      self.simple_name = self.raw
      for r in SIMPLE_NAME_REs:
        if self.cls in r[0]:
          for p in r[1]:
            exp = re.compile(p[0], re.UNICODE + re.IGNORECASE)
            self.simple_name = exp.sub(p[1], self.simple_name)


        

class OktmoOkatoObj(Base):
  __tablename__ = 'oktmo_okato'
  oktmo = C(Unicode(8), primary_key=True)
  okato = C(Unicode(11), primary_key=True)
  settlement_name = C(Unicode(100))

metadata = Base.metadata

def reader(src, lookup=None):  
  first = True  
  for l in src:
    i = l.decode('utf-8')[:-1]
    if i == '':                            # пустая строка, след запись по октмо
      first = True                         # а это был разделитель
      continue
      
    if first:                              # в строке запись ОКТМО
      first = False                        # след. будет НП по ОКАТО
      (code, raw) = i.split("\t")
      obj = OktmoObj()
      obj.code = code
      obj.raw = raw
      obj.parse(lookup=lookup)
      
      yield obj
      
    else:                                  # это запись по ОКАТО
      a = i.split("\t")
      if len(a) == 1:                      # нет кода имени НП
        okato_code = a[0]
        settlement_name = None
      else:                                # есть и код и имя
        (okato_code, settlement_name) = a

      # непонятная странность: коды ОКАТО в ОКТМО дополнены нулями
      # до 11 разрядов, но смысла в этом мало очень,
      # т.к. коды получаются уровня НП в сельсовете даже для городов  
      if len(okato_code) == 11 and okato_code.endswith('000'):
        okato_code = okato_code[:-3]  

      obj_okato = OktmoOkatoObj()
      obj_okato.oktmo = obj.code
      obj_okato.okato = okato_code
      obj_okato.settlement_name = settlement_name

      yield obj_okato


