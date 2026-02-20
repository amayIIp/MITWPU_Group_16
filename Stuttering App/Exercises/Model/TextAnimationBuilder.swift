//
//  TextAnimationBuilder.swift
//  Stuttering App 1
//
//  Generates attributed text for different animation types
//

import UIKit

class TextAnimationBuilder {
    
    private var fullWord: String = ""
    private var firstSyllable: String = ""
    private var secondSyllable: String = ""
    
    private let normalSize: CGFloat = 48
    private let normalWeight: UIFont.Weight = .bold
    private let normalColor: UIColor = .buttonTheme
    
    private let fadedAlpha: CGFloat = 0.5
    
    init(syllableWord: String) {
        parseSyllables(syllableWord)
    }
    
    private func parseSyllables(_ word: String) {
        let components = word.components(separatedBy: "-")
        
        if components.count >= 2 {
            firstSyllable = components[0]
            secondSyllable = components[1]
            fullWord = components.joined()  // "Ba" + "by" = "Baby"
        } else {
            // Fallback for words without hyphens
            fullWord = word
            firstSyllable = String(word.prefix(1))
            secondSyllable = String(word.dropFirst())
        }
    }
    
    // Type 1: Full Word - "Baby"
    func generateFullWord() -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: normalSize, weight: normalWeight),
            .foregroundColor: normalColor
        ]
        return NSAttributedString(string: fullWord, attributes: attributes)
    }
    
    // Type 2: Fade Second Part - "B(1.0)aby(0.5)"
    func generateFadedSecondPart() -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        let firstAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: normalSize, weight: normalWeight),
            .foregroundColor: normalColor
        ]
        result.append(NSAttributedString(string: firstSyllable, attributes: firstAttributes))
        
        let secondAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: normalSize, weight: normalWeight),
            .foregroundColor: normalColor.withAlphaComponent(fadedAlpha)
        ]
        result.append(NSAttributedString(string: secondSyllable, attributes: secondAttributes))
        
        return result
    }
    
    // Type 3: Highlight First Syllable Only - "Ba"
    func generateHighlightFirst() -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: normalSize, weight: normalWeight),
            .foregroundColor: normalColor
        ]
        return NSAttributedString(string: firstSyllable, attributes: attributes)
    }
    
    // Type 4: Elongated Syllable - "Baaa..."
    func generateElongated() -> NSAttributedString {
        guard let lastChar = firstSyllable.last else {
            return generateHighlightFirst()
        }
        
        let elongatedText = firstSyllable + String(repeating: Character(String(lastChar).lowercased()), count: 3) + "..."
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: normalSize, weight: normalWeight),
            .foregroundColor: normalColor
        ]
        return NSAttributedString(string: elongatedText, attributes: attributes)
    }
    
    // Type 5: Prefixed Word - "Baaaby"
    func generatePrefixedWord() -> NSAttributedString {
        guard let lastChar = firstSyllable.last else {
            return generateFullWord()
        }
        
        let prefix = firstSyllable + String(repeating: Character(String(lastChar).lowercased()), count: 3)
        let prefixedText = prefix + secondSyllable
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: normalSize, weight: normalWeight),
            .foregroundColor: normalColor
        ]
        return NSAttributedString(string: prefixedText, attributes: attributes)
    }
    
    func generateText(for type: AnimationType) -> NSAttributedString {
        switch type {
        case .fullWord:
            return generateFullWord()
        case .fadeSecondPart:
            return generateFadedSecondPart()
        case .highlightFirst:
            return generateHighlightFirst()
        case .elongate:
            return generateElongated()
        case .prefixedWord:
            return generatePrefixedWord()
        case .transition:
            return generateFullWord()
        }
    }
}
