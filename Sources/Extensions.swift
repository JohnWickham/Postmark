//
//  Extensions.swift
//
//
//  Created by John Wickham on 4/15/24.
//

import Foundation

extension String {
    
    func leadingWords(_ count: Int) -> String {
        
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
    }
    
}
