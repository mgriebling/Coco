/*-------------------------------------------------------------------------
    ParserGen.swift -- Generation of the Recursive Descent Parser
    Compiler Generator Coco/R,
    Copyright (c) 1990, 2004 Hanspeter Moessenboeck, University of Linz
    extended by M. Loeberbauer & A. Woess, Univ. of Linz
    with improvements by Pat Terry, Rhodes University
    Swift port by Michael Griebling, 2015

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the
    Free Software Foundation; either version 2, or (at your option) any
    later version.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
    for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

    As an exception, it is allowed to write an extension of Coco/R that is
    used as a plugin in non-free software.

    If not otherwise stated, any source code generated by Coco/R (other than
    Coco/R itself) does not fall under the GNU General Public License.
-------------------------------------------------------------------------*/

import Foundation

open class ParserGen {
    
    let maxTerm = 3		// sets of size < maxTerm are enumerated
    let CR : Character = "\r"
    let LF : Character = "\n"
    let EOF = -1
    
    let tErr = 0			// error codes
    let altErr = 1
    let syncErr = 2
    
    open var usingPos: Position? // "using" definitions from the attributed grammar
    
    var errorNr : Int           // highest parser error number
    var curSy : Symbol          // symbol whose production is currently generated
    var fram: InputStream?    // parser frame file
	var gen: OutputStream?	// generated parser source file
    var err = StringWriter()    // generated parser error messages
    var symSet = [BitArray]()
    
    var tab : Tab               // other Coco objects
    var trace: OutputStream
    var errors: Errors
    var buffer: Buffer
    
    public init (parser: Parser) {
        tab = parser.tab
        errors = parser.errors
        trace = parser.trace!
        buffer = parser.scanner.buffer!
        errorNr = -1
        usingPos = nil
        err = StringWriter()
        curSy = Symbol()
    }
    
    func Indent (_ n: Int) {
		if n == 0 { return }  // why doesn't Swift just not iterate
        for _ in 1...n { gen?.Write("\t") }
    }
    
    func Overlaps(_ s1: BitArray, _ s2: BitArray) -> Bool {
        let len = s1.count
        for i in 0..<len {
            if s1[i] && s2[i] {
                return true
            }
        }
        return false
    }
    
    // use a switch if more than 5 alternatives and none starts with a resolver, and no LL1 warning
    func UseSwitch (_ p: Node?) -> Bool {
        var s1, s2: BitArray
        var p = p
        if p!.typ != Node.alt { return false }
        var nAlts = 0
        s1 = BitArray(tab.terminals.count)
        while let pn = p {
            s2 = tab.Expected0(pn.sub!, curSy: curSy)
            // must not optimize with switch statement, if there are ll1 warnings
            if Overlaps(s1, s2) { return false }
            s1.or(s2)
            nAlts += 1
            // must not optimize with switch-statement, if alt uses a resolver expression
            if pn.sub!.typ == Node.rslv { return false }
            p = pn.down
        }
        return nAlts > 5;
    }
    
    func CopySourcePart (_ pos: Position?, indent: Int) {
        // Copy text described by pos from atg to gen
        var ch: Int
        if let pos = pos {
            buffer.Pos = pos.beg; ch = buffer.Read()
            if tab.emitLines {
                gen?.WriteLine()
                gen?.WriteLine("#line \(pos.line) \"\(tab.srcName)\"")
            }
            Indent(indent)
            done: while buffer.Pos <= pos.end {
                while ch == CR || ch == LF {  // eol is either CR or CRLF or LF
                    gen?.WriteLine(); Indent(indent)
                    if ch == CR { ch = buffer.Read() } // skip CR
                    if ch == LF { ch = buffer.Read() } // skip LF
                    var i = 1
                    while i <= pos.col && (ch == " " || ch == "\t") {
                        // skip blanks at beginning of line
                        ch = buffer.Read()
                        i += 1
                    }
                    if buffer.Pos > pos.end { break done }
                }
                gen?.Write(String(Character(ch)))
                ch = buffer.Read()
            }

            if indent > 0 { gen?.WriteLine() }
        }
    }
    
    func GenErrorMsg (_ errTyp: Int, sym: Symbol) {
        errorNr += 1
        err.Write("\t\tcase \(errorNr): s = \"")
        switch errTyp {
        case tErr:
            if sym.name[0] == "\"" { err.Write(tab.Escape(sym.name) + " expected") }
            else { err.Write(sym.name + " expected") }
        case altErr: err.Write("invalid " + sym.name)
        case syncErr: err.Write("this symbol not expected in " + sym.name)
        default: break
        }
        err.WriteLine("\"")
    }

    func NewCondSet (_ s: BitArray) -> Int {
        for i in 1..<symSet.count { // skip symSet[0] (reserved for union of SYNC sets)
            if Sets.Equals(s, b: symSet[i]) { return i }
        }
		symSet.append(s.Clone())
        return symSet.count - 1
    }
    
    func isValidName (_ sym: Symbol) -> Bool {
        let name = sym.name.replacingOccurrences(of: "\"", with: "")
        for (num, ch) in name.enumerated() {
            if num == 0 && !ch.isLetter() { return false }
            else if !ch.isAlphanumeric() { return false }
        }
        return true
    }
    
    func GenToken (_ sym: Symbol) {
        if sym.name[0].isLetter() { gen?.Write("_" + sym.name) }
        else if isValidName(sym) { gen?.Write("_" + sym.name.replacingOccurrences(of: "\"", with: "")) }
        else { gen?.Write("\(sym.n) /* \(sym.name) */") }
    }
    
    func GenCond (_ s: BitArray, p: Node) {
        if p.typ == Node.rslv { CopySourcePart(p.pos, indent: 0) }
        else {
            var n = Sets.Elements(s)
            if n == 0 { gen?.Write("false") } // happens if an ANY set matches no symbol
            else if n <= maxTerm {
                for sym in tab.terminals {
                    if s[sym.n] {
                        gen?.Write("la.kind == "); GenToken(sym)
                        n -= 1
                        if n > 0 { gen?.Write(" || ") }
                    }
                }
            } else {
                gen?.Write("StartOf(\(NewCondSet(s)))")
            }
        }
    }
    
    func PutCaseLabels (_ s: BitArray) {
        var oneLabel = false
        gen?.Write("case ");
        for sym in tab.terminals {
            if s[sym.n] {
                if oneLabel { gen?.Write(", ") }
                GenToken(sym); oneLabel = true
            }
        }
        gen?.Write(": ")
    }

    func GenCode (_ p: Node?, indent: Int, isChecked: BitArray ) {
        var p2: Node?
        var p = p
        var s1, s2: BitArray
        while let pn = p {
            switch pn.typ {
            case Node.nt:
                Indent(indent);
                gen?.Write(pn.sym!.name + "(")
                CopySourcePart(pn.pos, indent: 0)
                gen?.WriteLine(")")
            case Node.t:
                Indent(indent);
                // assert: if isChecked[p.sym.n] is true, then isChecked contains only p.sym.n
                if isChecked[pn.sym!.n] { gen?.WriteLine("Get()") }
                else { gen?.Write("Expect("); GenToken(pn.sym!); gen?.WriteLine(")") }
            case Node.wt:
                Indent(indent);
                s1 = tab.Expected(pn.next, curSy: curSy)
				let s3 = s1.Clone()
				let s4 = tab.allSyncSets
                s3.or(s4)
				s1 = s3
                gen?.Write("ExpectWeak("); GenToken(pn.sym!); gen?.WriteLine(", \(NewCondSet(s1)))")
            case Node.any:
                Indent(indent)
                let acc = Sets.Elements(pn.set)
                if tab.terminals.count == (acc + 1) || (acc > 0 && Sets.Equals(pn.set, b:isChecked)) {
                    // either this ANY accepts any terminal (the + 1 = end of file), or exactly what's allowed here
                    gen?.WriteLine("Get()")
                } else {
                    GenErrorMsg(altErr, sym: curSy)
                    if acc > 0 {
                        gen?.Write("if "); GenCond(pn.set, p: pn); gen?.WriteLine(" { Get() } else { SynErr(\(errorNr)) }")
                    } else { gen?.WriteLine("SynErr(\(errorNr)) // ANY node that matches no symbol") }
                }
            case Node.eps: break // nothing
            case Node.rslv: break // nothing
            case Node.sem:
                CopySourcePart(pn.pos, indent: indent)
            case Node.sync:
                Indent(indent)
                GenErrorMsg(syncErr, sym: curSy)
                s1 = pn.set.Clone()
                gen?.Write("while !("); GenCond(s1, p: pn); gen?.Write(") {")
                gen?.Write(" SynErr(\(errorNr)); Get() "); gen?.WriteLine("}")

            case Node.alt:
                s1 = tab.First(pn)
                let equal = Sets.Equals(s1, b: isChecked)
                let useSwitch = UseSwitch(pn)
                if useSwitch { Indent(indent); gen?.WriteLine("switch la.kind {") }
                p2 = pn
                while let pn2 = p2 {
                    s1 = tab.Expected(pn2.sub, curSy: curSy)
                    Indent(indent)
                    if useSwitch {
                        PutCaseLabels(s1); gen?.WriteLine()
                    } else if pn2 === pn {
                        gen?.Write("if "); GenCond(s1, p: pn2.sub!); gen?.WriteLine(" {")
                    } else if pn2.down == nil && equal {
						gen?.WriteLine("} else {")
                    } else {
                        gen?.Write("} else if ");  GenCond(s1, p: pn2.sub!); gen?.WriteLine(" {")
                    }
                    GenCode(pn2.sub, indent: indent + 1, isChecked: s1)
                    p2 = pn2.down
                }
                Indent(indent)
                if equal {
                    gen?.WriteLine("}")
                } else {
                    GenErrorMsg(altErr, sym: curSy)
                    if useSwitch {
                        gen?.WriteLine("default: SynErr(\(errorNr))")
                        Indent(indent); gen?.WriteLine("}")
                    } else {
                        gen?.Write("} "); gen?.WriteLine("else { SynErr(\(errorNr)) }")
                    }
                }
            case Node.iter:
                Indent(indent)
                p2 = pn.sub
                gen?.Write("while ")
                if p2!.typ == Node.wt {
                    s1 = tab.Expected(p2!.next, curSy: curSy)
                    s2 = tab.Expected(pn.next, curSy: curSy)
                    gen?.Write("WeakSeparator("); GenToken(p2!.sym!); gen?.Write(",\(NewCondSet(s1)),\(NewCondSet(s2)))")
                    s1 = BitArray(tab.terminals.count)  // for inner structure
                    if p2!.up || p2!.next == nil { p2 = nil } else { p2 = p2!.next }
                } else {
                    s1 = tab.First(p2)
                    GenCond(s1, p: p2!)
                }
                gen?.WriteLine(" {")
                GenCode(p2, indent: indent + 1, isChecked: s1)
                Indent(indent); gen?.WriteLine("}")
            case Node.opt:
                s1 = tab.First(pn.sub)
                Indent(indent)
                gen?.Write("if "); GenCond(s1, p: pn.sub!); gen?.WriteLine(" {")
                GenCode(pn.sub, indent: indent + 1, isChecked: s1)
                Indent(indent); gen?.WriteLine("}")
            default: break
            }
            if pn.typ != Node.eps && pn.typ != Node.sem && pn.typ != Node.sync {
                isChecked.SetAll(false)
            }
            if pn.up { break }
            p = pn.next
        }
    }

    func GenTokens() {
        for sym in tab.terminals {
            if sym.name[0].isLetter() {
                gen?.WriteLine("\tpublic let _\(sym.name) = \(sym.n)")
            } else if isValidName(sym) {
                gen?.WriteLine("\tpublic let _" + sym.name.replacingOccurrences(of: "\"", with: "") + " = \(sym.n)")
            }
        }
    }
    
    func GenPragmas() {
        for sym in tab.pragmas {
            gen?.WriteLine("\tpublic let _\(sym.name) = \(sym.n)")
        }
    }
    
    func GenCodePragmas() {
        for sym in tab.pragmas {
            gen?.Write("\t\t\t\tif la.kind == "); GenToken(sym); gen?.WriteLine(" {")
            CopySourcePart(sym.semPos, indent: 5)
            gen?.WriteLine("\t\t\t\t}")
        }
    }
    
    func GenProductions() {
        for sym in tab.nonterminals {
            curSy = sym;
            gen?.Write("\tfunc \(sym.name)(")
            CopySourcePart(sym.attrPos, indent: 0)
            gen?.WriteLine(") {")
            CopySourcePart(sym.semPos, indent: 2)
            GenCode(sym.graph, indent: 2, isChecked: BitArray(tab.terminals.count))
            gen?.WriteLine("\t}"); gen?.WriteLine()
        }
    }
    
    func InitSets() {
        for (i, s) in symSet.enumerated() {
            gen?.Write("\t\t[")
            var j = 0
            for sym in tab.terminals {
                if s[sym.n] { gen?.Write("_T,") } else { gen?.Write("_x,") }
                j += 1
                if j%4 == 0 { gen?.Write(" ") }
            }
            if i == symSet.count-1 { gen?.WriteLine("_x]") } else { gen?.WriteLine("_x],") }
        }
    }

    open func WriteParser () {
        let g = Generator(tab: tab)
        let oldPos = buffer.Pos  // Pos is modified by CopySourcePart
        symSet.append(tab.allSyncSets)
        
        fram = g.OpenFrame("Parser.frame")
        gen = g.OpenGen("Parser.swift")
        for sym in tab.terminals { GenErrorMsg(tErr, sym: sym) }
        
        g.GenCopyright()
        g.SkipFramePart("-->begin")
        
        if usingPos != nil { CopySourcePart(usingPos, indent: 0); gen?.WriteLine() }
        g.CopyFramePart("-->namespace")
        /* AW open namespace, if it exists */
        if !tab.nsName.isEmpty {
            gen?.WriteLine("namespace \(tab.nsName) {{")
            gen?.WriteLine()
        }
        g.CopyFramePart("-->constants")
        GenTokens() /* ML 2002/09/07 write the token kinds */
        gen?.WriteLine("\tpublic let maxT = \(tab.terminals.count-1)")
        GenPragmas() /* ML 2005/09/23 write the pragma kinds */
        g.CopyFramePart("-->declarations"); CopySourcePart(tab.semDeclPos, indent: 1)
        g.CopyFramePart("-->pragmas"); GenCodePragmas()
        g.CopyFramePart("-->productions"); GenProductions()
        g.CopyFramePart("-->parseRoot"); gen?.WriteLine("\t\t\(tab.gramSy!.name)()");
        if tab.checkEOF { gen?.WriteLine("\t\tExpect(_EOF)") }
        g.CopyFramePart("-->initialization"); InitSets()
        g.CopyFramePart("-->errors"); gen?.Write(err.string)
        g.CopyFramePart("")
        /* AW 2002-12-20 close namespace, if it exists */
        if !tab.nsName.isEmpty { gen?.Write("}") }
        gen?.close()
        buffer.Pos = oldPos
    }
    
    open func WriteStatistics () {
        trace.WriteLine();
        trace.WriteLine("\(tab.terminals.count) terminals")
        trace.WriteLine("\(tab.terminals.count + tab.pragmas.count + tab.nonterminals.count) symbols")
        trace.WriteLine("\(tab.nodes.count) nodes")
        trace.WriteLine("\(symSet.count) sets")
    }
    
    
} // end ParserGen

open class StringWriter {
    
    var stream: String = ""

	open func Write(_ s: String) { print(s, terminator: "", to: &stream) }
	open func WriteLine(_ s: String = "") { Write(s + "\n") }
	
    open var string : String { return stream }
    
}
