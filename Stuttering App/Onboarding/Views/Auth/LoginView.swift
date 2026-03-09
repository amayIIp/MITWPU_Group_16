//
//  LoginView.swift
//  Stuttering App
//

import SwiftUI
import Supabase

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isShowingSignup = false
    
    // Simulating access to the global Supabase client
    private let client = SupabaseManager.shared.client
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Welcome Back")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button(action: signIn) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Sign In")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                
                NavigationLink(destination: SignupView(), isActive: $isShowingSignup) {
                    Text("Don't have an account? Sign up")
                        .foregroundColor(.blue)
                }
                .padding(.top)
                
                Spacer()
            }
            .padding(.top, 50)
            .navigationBarHidden(true)
        }
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await client.auth.signIn(email: email, password: password)
                
                // Trigger global sync on login
                SupabaseSyncManager.shared.syncAllDataFromCloud { result in
                    switch result {
                    case .success:
                        print("Synced entirely")
                        // Post notification or change AppState to show main app
                        NotificationCenter.default.post(name: NSNotification.Name("UserLoggedIn"), object: nil)
                    case .failure(let error):
                        self.errorMessage = "Sync failed: \(error.localizedDescription)"
                    }
                }
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// SwiftUI Preview Fallback
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
