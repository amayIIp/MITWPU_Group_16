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
    
    // MARK: - Keys
    private let phonemesKey = "userSelectedPhonemes"
    private let firstNameKey = "userFirstName"
    private let lastNameKey = "userLastName"
    private let mobNoKey = "userMobNo"
    private let emailKey = "userEmail"
    private let dobKey = "userDob"
    private let passwordKey = "userPassword"
    
    
    private init() {}
    
    // MARK: - Phoneme Functions
    
    func savePhonemes(_ phonemes: [String]) {
        defaults.set(phonemes, forKey: phonemesKey)
    }
    
    func getPhonemes() -> [String] {
        return defaults.stringArray(forKey: phonemesKey) ?? []
    }
    
    func clearPhonemes() {
        defaults.removeObject(forKey: phonemesKey)
    }
    
    func saveName(_ name: String) {
        defaults.set(name, forKey: firstNameKey)
    }
    
    func getName() -> String? {
        return defaults.string(forKey: firstNameKey)
    }
    
    func clearName() {
        defaults.removeObject(forKey: firstNameKey)
    }
    
    // Last Name
    func saveLastName(_ name: String) {
        defaults.set(name, forKey: lastNameKey)
    }
    
    func getLastName() -> String? {
        return defaults.string(forKey: lastNameKey)
    }
    
    func clearLastName() {
        defaults.removeObject(forKey: lastNameKey)
    }
    
    // Mobile No
    func saveMobNo(_ name: String) {
        defaults.set(name, forKey: mobNoKey)
    }
    
    func getMobNo() -> String? {
        return defaults.string(forKey: mobNoKey)
    }
    
    func clearMobNo() {
        defaults.removeObject(forKey: mobNoKey)
    }
    
    // Email
    func saveEmail(_ name: String) {
        defaults.set(name, forKey: emailKey)
    }
    
    func getEmail() -> String? {
        return defaults.string(forKey: emailKey)
    }
    
    func clearEmail() {
        defaults.removeObject(forKey: emailKey)
    }
    
    // DOB
    func saveDob(_ name: String) {
        defaults.set(name, forKey: dobKey)
    }
    
    func getDob() -> String? {
        return defaults.string(forKey: dobKey)
    }
    
    func clearDob() {
        defaults.removeObject(forKey: dobKey)
    }
    
    // Password
    func savePassword(_ name: String) {
        defaults.set(name, forKey: passwordKey)
    }
    
    func getPassword() -> String? {
        return defaults.string(forKey: passwordKey)
    }
    
    func clearPassword() {
        defaults.removeObject(forKey: passwordKey)
    }
    
}
