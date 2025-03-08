//
//  SignUpView.swift
//  Aldo
//
//  Created by Andrew Katsifis on 6/12/24.
//
import SwiftUI
import Firebase
import FirebaseAuth

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.presentationMode) var presentationMode
    
    // User Input Fields
    @State private var username: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var phoneNumber: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    @State private var profilePicture: UIImage? = nil
    
    // UI States
    @State private var showImagePicker = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    @State private var showSuccessAlert = false
    
    // Validation
    let prohibitedWords = ["badword1", "badword2"] // Replace with actual list
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                // Profile Picture Selector
                VStack {
                    if let profilePicture = profilePicture {
                        Image(uiImage: profilePicture)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                            .shadow(radius: 5)
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.gray)
                    }
                    
                    Button(action: {
                        showImagePicker = true
                    }) {
                        Text("Select Profile Picture")
                            .foregroundColor(.blue)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.bottom, 10)
                
                // Form Fields
                Group {
                    CustomTextField(placeholder: "Username", text: $username, icon: "person")
                    
                    HStack {
                        CustomTextField(placeholder: "First Name", text: $firstName, icon: "person.text.rectangle")
                            .frame(maxWidth: .infinity)
                        
                        CustomTextField(placeholder: "Last Name", text: $lastName, icon: "person.text.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    
                    CustomTextField(placeholder: "Email", text: $email, icon: "envelope")
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    CustomSecureField(placeholder: "Password", text: $password, icon: "lock")
                    
                    CustomSecureField(placeholder: "Confirm Password", text: $confirmPassword, icon: "lock.shield")
                    
                    CustomTextField(placeholder: "Phone Number", text: $phoneNumber, icon: "phone")
                        .keyboardType(.phonePad)
                    
                    CustomTextField(placeholder: "Location", text: $location, icon: "location")
                    
                    CustomTextEditor(placeholder: "Bio - Tell us about yourself", text: $bio)
                        .frame(height: 100)
                }
                
                // Error Message
                if showError {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }
                
                // Sign Up Button
                Button(action: signUp) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .padding(.vertical, 10)
                    } else {
                        Text("Create Account")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(isProcessing ? Color.gray : Color.blue)
                .cornerRadius(10)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .disabled(isProcessing)
                
                // Already have an account button
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Already have an account? Sign In")
                        .foregroundColor(.blue)
                        .padding(.vertical, 10)
                }
            }
            .padding()
        }
        .alert(isPresented: $showSuccessAlert) {
            Alert(
                title: Text("Account Created"),
                message: Text("Your account has been created successfully!"),
                dismissButton: .default(Text("OK")) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $profilePicture)
        }
        .onAppear {
            // Perform any setup needed
        }
    }
    
    private func signUp() {
        // Reset error state
        showError = false
        errorMessage = ""
        
        // Validate inputs
        guard validateInputs() else { return }
        
        // Set processing state
        isProcessing = true
        
        // First create the authentication account
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                handleError(error.localizedDescription)
                return
            }
            
            guard let user = authResult?.user else {
                handleError("Failed to create user account")
                return
            }
            
            // Now use UserService to save the full profile with image
            UserService.shared.createUser(
                email: email,
                username: username,
                firstName: firstName,
                lastName: lastName,
                phoneNumber: phoneNumber,
                bio: bio,
                location: location,
                profileImage: profilePicture
            ) { result in
                isProcessing = false
                
                switch result {
                case .success(let userModel):
                    // Show success and dismiss
                    showSuccessAlert = true
                    
                case .failure(let error):
                    // Handle error
                    handleError(error.localizedDescription)
                    
                    // Since authentication was created but profile failed, we should delete the auth account
                    user.delete { error in
                        if let error = error {
                            print("Failed to clean up auth account: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    private func validateInputs() -> Bool {
        // Check required fields
        if username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty {
            handleError("Please fill in all required fields")
            return false
        }
        
        // Validate password match
        if password != confirmPassword {
            handleError("Passwords do not match")
            return false
        }
        
        // Validate password length
        if password.count < 6 {
            handleError("Password must be at least 6 characters")
            return false
        }
        
        // Validate email format
        if !isValidEmail(email) {
            handleError("Please enter a valid email address")
            return false
        }
        
        // Validate username
        for word in prohibitedWords {
            if username.lowercased().contains(word) {
                handleError("Username contains prohibited language")
                return false
            }
        }
        
        return true
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func handleError(_ message: String) {
        isProcessing = false
        errorMessage = message
        showError = true
    }
}

// MARK: - Custom Input Components

struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    var icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .padding(.leading, 5)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct CustomSecureField: View {
    var placeholder: String
    @Binding var text: String
    var icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            
            SecureField(placeholder, text: $text)
                .padding(.leading, 5)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct CustomTextEditor: View {
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
            }
            
            TextEditor(text: $text)
                .padding(4)
        }
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .environmentObject(AuthenticationManager())
    }
}
