//
//  SupabaseManager.swift
//  Stuttering App
//

import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    private let supabaseURL = URL(string: "https://zolaxhyjzkvupkmogdpo.supabase.co")!
    private let supabaseKey = "sb_publishable_kqZYPg1jnKQEXEYn0OS1Lw_m8Z3aYKP"
    
    let client: SupabaseClient
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: .init( // ✅ Let Xcode infer the exact nested type here
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
    
    var currentUser: User? {
        return client.auth.currentUser
    }
}
