//
//  StorageManager.swift
//  Spasht
//
//  Created by Prathamesh Patil on 16/11/25.
//

import Foundation

class StorageManager {
    static let shared = StorageManager()
    private let defaults = UserDefaults.standard
    private let phonemesKey = "userSelectedPhonemes"
    
    private init() {}
    
    func savePhonemes(_ phonemes: [String]) {
        defaults.set(phonemes, forKey: phonemesKey)
    }
    
    func getPhonemes() -> [String] {
        return defaults.stringArray(forKey: phonemesKey) ?? []
    }
    
    func clearPhonemes() {
        defaults.removeObject(forKey: phonemesKey)
    }
}
