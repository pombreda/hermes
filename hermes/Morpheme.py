class Morpheme:
  def __init__(self, string, id=0):
    self.__dict__.update(locals())

class NonTerminal(Morpheme):
  def __init__(self, string, id=0):
    super().__init__(string, id)
    self.macro = None # Is this nonterminal the root of a macro expansion?
  def id(self):
    return self.id
  def setMacro(self, macro):
    self.macro = macro
  def __str__(self):
    return self.string
  def first(self):
    return 

class Terminal(Morpheme):
  def id(self):
    return self.id
  def __str__(self):
    return "'" + self.string + "'"
  def first(self):
    return {self}

class AbstractTerminal(Terminal):
  pass

class EmptyString(AbstractTerminal):
  def __init__(self, id):
    super().__init__('ε', id)
  def __str__(self):
    return 'ε'

class EndOfStream(AbstractTerminal):
  def __init__(self, id):
    super().__init__('σ', id)
  def __str__(self):
    return 'σ'

class Expression(AbstractTerminal):
  def __init__(self, id):
    super().__init__('λ', id)
  def __str__(self):
    return 'λ'
