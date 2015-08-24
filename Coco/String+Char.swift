//
//  String+Char.swift
//  QuadReal
//
//  Created by Mike Griebling on 1 Jul 2015.
//  Copyright (c) 2015 Computer Inspirations. All rights reserved.
//

import Foundation

public extension String {
	
	// Extensions to make it easier to work with C-style strings
	
	public subscript (n: Int) -> Character {
		get {
			let s = advance(self.startIndex, n)
			if s < self.endIndex {
				return self[s]
			}
			return "\0"
		}
		set {
			let s = advance(self.startIndex, n)
			if s < self.endIndex {
				self = self.substringToIndex(s) + "\(newValue)" + self.substringFromIndex(s.successor())
			}
		}
	}
	
	public func count() -> Int { return self.characters.count }
	
	public func stringByTrimmingTrailingCharactersInSet (characterSet: NSCharacterSet) -> String {
		if let rangeOfLastWantedCharacter = self.rangeOfCharacterFromSet(characterSet.invertedSet, options:.BackwardsSearch) {
			return self.substringToIndex(rangeOfLastWantedCharacter.endIndex)
		}
		return ""
	}
    
    public func substring (from: Int, _ length: Int) -> String {
        let str : NSString = self
        return str.substringWithRange(NSMakeRange(from, length))
    }
    
    public func contains (s: String) -> Bool {
        let str : NSString = self
        return str.containsString(s)
    }
	
}

public extension Character {

	public func unicodeValue() -> Int {
		for s in String(self).unicodeScalars {
			return Int(s.value)
		}
		return 0
	}
    
    public func isLetter() -> Bool {
        let cSet = NSCharacterSet.letterCharacterSet()
        return cSet.characterIsMember(self.toUnichar())
    }
    
    public var lowercase : Character {
        let s = String(self)
        return s.lowercaseString.characters.first!
    }
	
	init(_ int: Int) {
		let s = String(UnicodeScalar(int))
		self = s[0]
	}
	
	public func add (n: Int) -> Character {
		let newCharacter = self.unicodeValue() + n
		return Character(newCharacter)
	}
	
	public func toUnichar () -> unichar {
		// Caution: this won't work for multi-char Characters
		return [unichar](String(self).utf16).first!
	}
	
}

func == (l: Int, r: Character) -> Bool { return l == r.unicodeValue() }
func == (l: Character, r: Int) -> Bool { return l.unicodeValue() == r }
func + (c: Character, inc: Int) -> Character { return c.add(inc) }
func - (c: Character, inc: Int) -> Character { return c.add(-inc) }
func - (c: Character, inc: Character) -> Int { return c.add(-inc.unicodeValue()).unicodeValue() }
func += (inout c: Character, inc: Int) { c = c + inc }
func -= (inout c: Character, inc: Int) { c = c - inc }
postfix func -- (c: Character) -> Character { return c - 1 }
postfix func ++ (c: Character) -> Character { return c + 1 }
