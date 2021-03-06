# Hermes Parser Generator

Hermes is a parser generator for LL(1) grammars with extensions to parse expressions. 

[![Build Status](https://secure.travis-ci.org/scottfrazer/hermes.png)](http://travis-ci.org/scottfrazer/hermes)
[![Coverage Status](https://coveralls.io/repos/scottfrazer/hermes/badge.png)](https://coveralls.io/r/scottfrazer/hermes)
[![Latest Version](https://pypip.in/v/hermes-parser/badge.png)](https://pypi.python.org/pypi/hermes-parser/)
[![License](https://pypip.in/license/hermes-parser/badge.png)](https://pypi.python.org/pypi/hermes-parser/)

# Quick Start

```
>>> import hermes
>>> with open('test.gr') as fp:
...     json_parser = hermes.compile(fp)
...
>>> tree = json_parser.parse('{"a": 1, "b": [2,3]}')
>>> print(tree.dumps(indent=2))
(json:
  (obj:
    <lbrace (line 1 col 1) `{`>,
    (_gen0:
      (key_value_pair:
        (key:
          <string (line 1 col 2) `"a"`>
        ),
        <colon (line 1 col 5) `:`>,
        (value:
          <integer (line 1 col 7) `1`>
        )
      ),
      (_gen1:
        <comma (line 1 col 8) `,`>,
        (key_value_pair:
          (key:
            <string (line 1 col 10) `"b"`>
          ),
          <colon (line 1 col 13) `:`>,
          (value:
            (list:
              <lsquare (line 1 col 15) `[`>,
              (_gen2:
                (value:
                  <integer (line 1 col 16) `2`>
                ),
                (_gen3:
                  <comma (line 1 col 17) `,`>,
                  (value:
                    <integer (line 1 col 18) `3`>
                  ),
                  (_gen3: )
                )
              ),
              <rsquare (line 1 col 19) `]`>
            )
          )
        ),
        (_gen1: )
      )
    ),
    <rbrace (line 1 col 20) `}`>
  )
)
>>> print(tree.toAst().dumps(indent=2))
(JsonObject:
  values=[
    (KeyValue:
      key=<string (line 1 col 2) `"a"`>,
      value=<integer (line 1 col 7) `1`>
    ),
    (KeyValue:
      key=<string (line 1 col 10) `"b"`>,
      value=(JsonList:
        values=[
          <integer (line 1 col 16) `2`>,
          <integer (line 1 col 18) `3`>
        ]
      )
    )
  ]
)
>>>
```

# Dependencies

* Python 3.4+
* moody-templates 0.9
* xtermcolor 1.2

# Installation

```bash
$ python setup.py install
```

Or, through pip:

```bash
$ pip install hermes-parser
```

# Documentation

For full documentation, go to: http://hermes.readthedocs.org/

## Introduction

Hermes is a parser generator that takes as input a grammar file and generates a parser in one of four target languages (Python, C, Java, JavaScript).  The generated code can be used as part of a separate code base or stand-alone via a front-end interface.

The following grammar will accept input, and return a parse tree, if the input tokens contains any number of `:a` tokens followed by the same number of `:b` tokens, followed by a terminating semicolon (`:semi`):

```
grammar {
  lexer<python> {
    r'a' -> :a
    r'b' -> :b
    r';' -> :semi
  }
  parser {
    $start = $sub :semi
    $sub = :a $sub :b | :_empty
  }
}
```

## Grammar File Specification

Grammar files are specified in Hermes Grammar Format that typically has the `.gr` extension.  A skeleton grammar file looks like this:

```
grammar {
  lexer<c> {
    ... lexer regular expressions ...
  }
  parser {
    ... rules ...
    $e = parser<expression> {
      ... expression rules ...
    }
  }
}
```

Breaking down the grammar definition a little bit

### Lexer definition

```
lexer<c> {
  "[a-z]+" -> :word
  "[0-9]+" -> :number
}
```

This defines that a lexer will be generated in the target language specified.  Inside the braces will be rules in the form of `regex -> terminal`.  In the example above, if the *beginning* of the input string matches "[a-z]+", then a `:word` terminal will be emitted from the lexical analyzer.  If the beginning of the input stream does not match "[a-z]+", then the next expression is tried.

The lexer is optional.  If one is not provided, then an external lexer needs to be provided that outputs the right data structures that the parser can understand.

Regular expressions for the lexer are language dependent.  Here are the supported languages and the way they interpret the regular expressions:

* Python: [regex](https://docs.python.org/3.4/library/re.html) module in standard library
* C: [libpcre2](http://www.pcre.org/)
* Java: [java.util.regex](http://docs.oracle.com/javase/7/docs/api/java/util/regex/package-summary.html).  Specifically, the parameter to [Pattern.compile()](http://docs.oracle.com/javase/7/docs/api/java/util/regex/Pattern.html#compile(java.lang.String))
* JavaScript: [RegExp()](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/RegExp) class

### LL(1) Parser Rules

LL(1) rules define how terminals (from the lexer) group together to form nonterminals.

The syntax for a grammar rule is an equality with a *single* nonterminal on the left hand and one or more terminals/nonterminals on the right side of the quality.  Then, there's an optional AST transformation.  For example, consider the grammar rule a Python-style for loop:

```
$loop = :for :identifier :in :identifier :colon list($statement) -> Loop(item=$1, collection=$3, body=%5)
```

This states that a `$loop` is made up of a `:for` terminal followed by `:identifier`, `:in`, `:identifier`, `:colon`, then a list of `$statement`, the definiton for which is omitted in this example.

If this rule matches, the last part of the rule defines the data structure to return.  This is called an Abstract Syntax Tree, or AST.  In this case, the AST definition is `Loop(item=$1, collection=$3, body=%5)`.  Abstract Syntax Trees add some more symantics while also filtering out unnecessary tokens (like `:in` and `:colon`).


Nonterminals must conform to the regular expression: `\$[a-zA-Z0-9_]+` (i.e. variable names preceded by a $)
Terminals must conform to the regular expression: `:[a-zA-Z0-9_]+` (i.e. variable names preceded by a :)

Here are some more examples of grammar rules:

```
$properties = :lbrace $items :rbrace
$items = :item $items_sub
$items_sub = :comma :item $items_sub
$items_sub = :_empty
```

Grammar rules can be combined for brevity:

```
$N = :a
$N = :b
```

Is the same as:

```
$N = :a | :b
```

The special terminal, `:_empty` refers to the empty string.  These rules are all equivalent:

```
$N = :a :_empty :b
$N = :a :b
$N = :_empty :a :_empty :b :_empty
```

### Expression Sub-Parsers

Sometimes LL(1) rules don't provide the flexibility to parse common structures.  One example of this is trying to parse mathematical expressions, such as `1+2*a-(b^2)`.  Attempting to write LL(1) grammar rules for this kind of expression, with order of operations, would result in a complex grammar or one full of conflicts.  For example, imagine the following rules:

```
$e = :number | :variable
(*:left) $e = $e :plus $e -> Add(l=$0, r=$2)
(-:left) $e = $e :dash $e -> Subtract(l=$0, r=$2)
(*:left) $e = $e :asterisk $e -> Multiply(l=$0, r=$2)
(-:left) $e = $e :slash $e -> Divide(l=$0, r=$2)
```

Right away we can see that there are conflicts in this grammar, suppose we were to try to parse the tokens `:number :plus :number`.  After the first `:number` is parsed, it's impossible to tell with one token of lookahead which of the infix-notation rules to choose.  We need to either have another token of lookahead or take another approach.

Expression parsers should be called *pivot parsing*.  Instead of interpreting each rule as one rule, interpret them as a rule with a pivot point.  I'll use the token `<=>` as the pivot signifier:

```
$e = :number | :variable
(*:left) $e = $e <=> :plus $e -> Add(l=$0, r=$2)
(-:left) $e = $e <=> :dash $e -> Subtract(l=$0, r=$2)
(*:left) $e = $e <=> :asterisk $e -> Multiply(l=$0, r=$2)
(-:left) $e = $e <=> :slash $e -> Divide(l=$0, r=$2)
```

This can alternatively be thought of as this:

```
$e = :number | :variable

         +--> (*:left) :plus $e -> Add(l=$0, r=$2)
         |
$e = $e -+--> (-:left) :dash $e -> Subtract(l=$0, r=$2)
         |
         +--> (*:left) :asterisk $e -> Multiply(l=$0, r=$2)
         |
         +--> (-:left) :slash $e -> Divide(l=$0, r=$2)
```

## Generating a Parser

Using the grammar from the introduction, we can generate a parser in the C programming language with the following command:

```bash
$ hermes generate --language=c --add-main grammar.zgr
```

The output of this command will be a bunch of .c and .h files in the current directory.  Compile the code as follows:

```bash
$ cc -o parser *.c -std=c99
```

## Running the Parser

As input, the parser needs a list of tokens.  Programmatically, the tokens can be specified as objects, but for running the main() method that Hermes generates, the tokens file format is defined to look like this:

```json
[
  {"terminal": "a", "line": 0, "col": 0, "resource": "tokens", "source_string": ""},
  {"terminal": "a", "line": 0, "col": 0, "resource": "tokens", "source_string": ""},
  {"terminal": "b", "line": 0, "col": 0, "resource": "tokens", "source_string": ""},
  {"terminal": "b", "line": 0, "col": 0, "resource": "tokens", "source_string": ""},
  {"terminal": "semi", "line": 0, "col": 0, "resource": "tokens", "source_string": ""}
]
```

This input specifies the following token stream: `a`, `a`, `b`, `b`, `semi`.

With the tokens file created (or generated), we can run our newly compiled parser and print out a parsetree (or syntax error):

```
$ cat tokens | ./parser grammar parsetree
(start:
  (sub:
    a,
    (sub:
      a,
      (sub: ),
      b
    ),
    b
  ),
  semi
)
```
