//
//  AppSecrets.example.swift
//  Stuttering App
//
//  Template for the real AppSecrets.swift, which is gitignored.
//
//      cp "Stuttering App/AppSecrets.example.swift" "Stuttering App/AppSecrets.swift"
//
//  then fill in the values below. Never commit the filled-in copy.
//
//  Values here are compiled into the binary as plain strings and can be
//  recovered from a shipped IPA. Only keys that are designed to be public
//  belong in this file.
//

import Foundation

struct AppSecrets {

    /// Supabase dashboard → Project Settings → API → publishable key.
    /// Publishable by design; safe to ship only while RLS is enabled on
    /// every table.
    static let supabaseKey = ""
}
