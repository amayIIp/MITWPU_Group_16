//
//  SignupView.swift
//  Stuttering App
//

import SwiftUI
import Supabase

struct SignupView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @Environment(\.presentationMode) var presentationMode
    
    private let client = SupabaseManager.shared.client
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Account")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            TextField("First Name", text: $firstName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                
            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button(action: signUp) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Sign Up")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            .disabled(isLoading || email.isEmpty || password.isEmpty || password != confirmPassword)
            
            Button("Already have an account? Sign in") {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.blue)
            .padding(.top)
            
            Spacer()
        }
        .padding(.top, 20)
    }
    
    private func signUp() {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await client.auth.signUp(
                    email: email,
                    password: password,
                    data: ["first_name": .string(firstName)]
                )
                
                print("Signed up: \(response.user.id.uuidString)")
                
                DispatchQueue.main.async {
                    // Navigate to next onboarding step or home
                    NotificationCenter.default.post(name: NSNotification.Name("UserLoggedIn"), object: nil)
                }
            } catch {
                print("Signup Error: \(error)")
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

struct SignupView_Previews: PreviewProvider {
    static var previews: some View {
        SignupView()
    }
}
