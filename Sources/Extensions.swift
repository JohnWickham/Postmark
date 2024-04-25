//
//  Extensions.swift
//
//
//  Created by John Wickham on 4/15/24.
//

import Foundation

extension String {
    
    private static let slugSafeCharacters = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-")
    
    func leadingWords(_ count: Int) -> String {
        // https://github.com/JohnWickham/Postmark/issues/1
        #if os(macOS)
        var substringRanges: [Range<String.Index>] = []
        self.enumerateSubstrings(in: self.startIndex..., options: .byWords) { _, substringRange, _, _ in
            substringRanges.append(substringRange)
        }
        
        let wordCount = 30
        
        if substringRanges.count > wordCount - 1 {
            return String(self[self.startIndex ..< substringRanges[wordCount - 1].upperBound])
        } else {
            return self
        }
        
        #elseif os(Linux)
        let maxCharacters = 175
        if self.count > maxCharacters - 1 {
            return String(self.prefix(maxCharacters))
        }
        else {
            return self
        }
        #endif
    }
    
    func makeSlug() -> String? {
        if let latin = self.applyingTransform(StringTransform("Any-Latin; Latin-ASCII;"), reverse: false) {
            let urlComponents = latin.components(separatedBy: String.slugSafeCharacters.inverted)
            let result = urlComponents.filter { $0 != "" }.joined(separator: "-")

            if result.count > 0 {
                return result
            }
        }
        
        return nil
    }
    
    func matchingSubstrings(usingRegex regex: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: .caseInsensitive) else {
            return []
        }
        
        let matches = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
        let matchStrings = matches.map { match in
           String(self[Range(match.range, in: self)!])
        }
        return matchStrings
    }
    
}

extension URL {
    
    func relativeURLForPath(_ pathArgument: String, directoryHint: URL.DirectoryHint) -> URL {
        // https://github.com/JohnWickham/Postmark/issues/1
        #if os(macOS)
        return URL(filePath: pathArgument, directoryHint: directoryHint, relativeTo: self)
        #elseif os(Linux)
        return URL(fileURLWithPath: pathArgument, isDirectory: true)
        #endif
    }
    
}
