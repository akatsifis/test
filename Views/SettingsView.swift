//
//  SettingsView.swift
//  Aldo
//
//  Created by Andrew Katsifis on 6/12/24.
//
import SwiftUI
import Firebase
import FirebaseStorage

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    // User data fields
    @State private var username: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    @State private var profilePicture: UIImage? = nil
    @State private var notificationsEnabled: Bool = true
    @State private var selectedLanguage: String = "English"
    @State private var newPassword: String = ""
    
    // UI States
    @State private var showImagePicker = false
    @State private var showAlert = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var hasChanges: Bool = false
    
    // List of prohibited words
    let prohibitedWords = ["badword1", "badword2"] // Replace with actual list of prohibited words
    
    // Language options
    let languages = ["English", "Spanish", "French", "German"]
    
    var body: some View {
        NavigationView {
            Form {
                // Profile Picture Section
                Section(header: Text("Profile Picture")) {
                    VStack {
                        if let profilePicture = profilePicture {
                            Image(uiImage: profilePicture)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                                .shadow(radius: 5)
                                .padding()
                        } else if let user = authManager.currentUser, let urlString = user.profilePicture, let url = URL(string: urlString) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                                    .shadow(radius: 5)
                                    .padding()
                            } placeholder: {
                                ProgressView()
                                    .frame(width: 120, height: 120)
                                    .padding()
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundColor(.gray)
                                .padding()
                        }

                        Button(action: {
                            showImagePicker = true
                        }) {
                            Text("Change Picture")
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Basic Info Section
                Section(header: Text("Basic Information")) {
                    TextField("Username", text: $username)
                        .onChange(of: username) { _ in hasChanges = true }
                    
                    TextField("First Name", text: $firstName)
                        .onChange(of: firstName) { _ in hasChanges = true }
                    
                    TextField("Last Name", text: $lastName)
                        .onChange(of: lastName) { _ in hasChanges = true }
                    
                    TextField("Email", text: $email)
                        .disabled(true) // Email is tied to authentication, so we disable it
                    
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .onChange(of: phoneNumber) { _ in hasChanges = true }
                    
                    TextField("Location", text: $location)
                        .onChange(of: location) { _ in hasChanges = true }
                }
                
                // Bio Section
                Section(header: Text("About You")) {
                    TextEditor(text: $bio)
                        .frame(height: 100)
                        .onChange(of: bio) { _ in hasChanges = true }
                }
                
                // Password Section
                Section(header: Text("Password")) {
                    SecureField("New Password (leave empty to keep current)", text: $newPassword)
                        .onChange(of: newPassword) { _ in hasChanges = true }
                    
                    if !newPassword.isEmpty {
                        Text("Password must be at least 6 characters")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Preferences Section
                Section(header: Text("Preferences")) {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _ in hasChanges = true }
                    
                    Picker("Language", selection: $selectedLanguage) {
                        ForEach(languages, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedLanguage) { _ in hasChanges = true }
                }
                
                // Save Button
                Section {
                    Button(action: saveSettings) {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Spacer()
                            }
                        } else {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(hasChanges ? Color.blue : Color.gray)
                    .cornerRadius(10)
                    .disabled(!hasChanges || isLoading)
                }
            }
            .navigationTitle("Settings")
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $profilePicture)
                    .onDisappear {
                        if profilePicture != nil {
                            hasChanges = true
                        }
                    }
            }
            .onAppear(perform: loadUserData)
        }
    }
    
    // Load User Data
    private func loadUserData() {
        guard let user = authManager.currentUser else { return }
        
        username = user.username
        firstName = user.firstName
        lastName = user.lastName
        email = user.email
        phoneNumber = user.phoneNumber
        bio = user.bio
        location = user.location
        notificationsEnabled = user.notificationsEnabled
        selectedLanguage = user.selectedLanguage
        
        // Reset changes flag
        hasChanges = false
    }
    
    // Save Settings
    private func saveSettings() {
        guard validateUsername() else { return }
        
        isLoading = true
        
        // Create an updated user model
        guard let currentUser = authManager.currentUser else {
            handleError("User data not found")
            return
        }
        
        // Upload profile picture if changed
        if let newImage = profilePicture {
            uploadProfileImage(image: newImage) { result in
                switch result {
                case .success(let imageURL):
                    updateUserData(currentUser, profilePictureURL: imageURL)
                case .failure(let error):
                    handleError("Failed to upload profile picture: \(error.localizedDescription)")
                }
            }
        } else {
            // Just update the user data without changing profile pic
            updateUserData(currentUser, profilePictureURL: currentUser.profilePicture)
        }
        
        // Update password if changed
        if !newPassword.isEmpty {
            updatePassword()
        }
    }
    
    // Upload profile image
    private func uploadProfileImage(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "SettingsView", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])))
            return
        }
        
        let storageRef = Storage.storage().reference().child("profile_images/\(UUID().uuidString).jpg")
        
        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let downloadURL = url else {
                    completion(.failure(NSError(domain: "SettingsView", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                    return
                }
                
                completion(.success(downloadURL.absoluteString))
            }
        }
    }
    
    // Update user data in Firestore
    private func updateUserData(_ user: Models.User, profilePictureURL: String?) {
        // Create new user with updated values
        let updatedUser = Models.User(
            id: user.id,
            username: username,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber,
            bio: bio,
            location: location,
            friends: user.friends,
            scores: user.scores,
            steps: user.steps,
            profilePicture: profilePictureURL,
            notificationsEnabled: notificationsEnabled,
            selectedLanguage: selectedLanguage
        )
        
        guard let userId = Auth.auth().currentUser?.uid else {
            handleError("User not authenticated")
            return
        }
        
        // Update user document in Firestore
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData(updatedUser.toDictionary()) { error in
            isLoading = false
            
            if let error = error {
                handleError("Failed to update profile: \(error.localizedDescription)")
            } else {
                // Update local user
                authManager.currentUser = updatedUser
                showSuccessAlert("Profile Updated", "Your profile information has been updated successfully.")
                hasChanges = false
            }
        }
    }
    
    // Update password
    private func updatePassword() {
        if newPassword.count < 6 {
            handleError("Password must be at least 6 characters")
            return
        }
        
        Auth.auth().currentUser?.updatePassword(to: newPassword) { error in
            if let error = error {
                handleError("Failed to update password: \(error.localizedDescription)")
            } else {
                newPassword = ""
                showSuccessAlert("Password Updated", "Your password has been updated successfully.")
            }
        }
    }
    
    // Validate Username
    private func validateUsername() -> Bool {
        // Check for prohibited words
        for word in prohibitedWords {
            if username.lowercased().contains(word) {
                handleError("Username contains prohibited language.")
                return false
            }
        }
        
        // Username length check
        if username.count < 3 {
            handleError("Username must be at least 3 characters.")
            return false
        }
        
        return true
    }
    
    // Handle Error
    private func handleError(_ message: String) {
        isLoading = false
        alertTitle = "Error"
        alertMessage = message
        showAlert = true
    }
    
    // Show Success Alert
    private func showSuccessAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AuthenticationManager())
    }
}
