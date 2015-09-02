# Coco
## Swift version of the Coco/R Compiler Generator

Coco/R is a compiler generator, which takes an attributed grammar of a source language and generates a 
scanner and a parser for this language. The scanner works as a deterministic finite automaton. The parser 
uses a recursive descent architecture. LL(1) conflicts can be resolved by a multi-symbol lookahead or by 
semantic checks. Thus the class of accepted grammars is LL(k) for an arbitrary k.

Coco/R is distributed under the terms of the GNU General Public License (slightly extended).

Swift port by Michael Griebling, 2015.
