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

## Testing the Coco/R Compiler Generator

1) Produce a new Coco executable by compiling Coco with Xcode.
2) Copy the files from the support directory to wherever the Coco executable resides.
3) Run Coco from the command line with: "./Coco Coco.atg"
4) New versions of the Parser.swift and Scanner.swift will be generated that
   implement the supplied Coco.atg grammar.
5) Copy the new parser/scanner swift files to the Coco Xcode project, replacing
   the original files.
6) Recompile and run Coco with the new files. The resultant Swift parser/scanner
   files should be identical to the original.
