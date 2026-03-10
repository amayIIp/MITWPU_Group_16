//
//  SupabaseManager.swift
//  Stuttering App
//

import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    // TODO: Replace with actual Supabase URL and Anon Key
    private let supabaseURL = URL(string: "https://zolaxhyjzkvupkmogdpo.supabase.co")!
    private let supabaseKey = "sb_publishable_kqZYPg1jnKQEXEYn0OS1Lw_m8Z3aYKP"
    
    let client: SupabaseClient
    
    private init() {
        self.client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
    }
    
    var currentUser: User? {
        return client.auth.currentUser
    }
}
