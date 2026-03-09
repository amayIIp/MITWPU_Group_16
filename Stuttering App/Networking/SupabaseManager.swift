//
//  SupabaseManager.swift
//  Stuttering App
//

import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    // TODO: Replace with actual Supabase URL and Anon Key
    private let supabaseURL = URL(string: "https://vmvsfyvcqsptxfvokvkh.supabase.co")!
    private let supabaseKey = "sb_publishable_fj5YHHkWcD7BOCRk4kvBkQ_1iRfFmFk"
    
    let client: SupabaseClient
    
    private init() {
        self.client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
    }
    
    var currentUser: User? {
        return client.auth.currentUser
    }
}
