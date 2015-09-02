# Coco/R
## Swift version of the Coco/R Compiler Generator

Coco/R is a compiler generator, which takes an attributed grammar of a source language and generates a 
scanner and a parser for this language. The scanner works as a deterministic finite automaton. The parser 
uses a recursive descent architecture. LL(1) conflicts can be resolved by a multi-symbol lookahead or by 
semantic checks. Thus the class of accepted grammars is LL(k) for an arbitrary k.

This Swift port has been used to successfully recreate its own parser and scanner from the included Coco.atg attributed grammar file.

Support for other languages and grammar examples are available from the University of Linz at http://www.ssw.uni-linz.ac.at/Coco/.

Coco/R is distributed under the terms of the GNU General Public License (slightly extended).

Swift port by Michael Griebling, 2015.
