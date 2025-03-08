import SwiftUI
import Firebase
import FirebaseStorage

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    // User data fields
    @State private var userModel: Models.User?
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
                        } else if let user = userModel, let urlString = user.profilePicture, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                                        .shadow(radius: 5)
                                        .padding()
                                } else if phase.error != nil {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 120, height: 120)
                                        .foregroundColor(.gray)
                                        .padding()
                                } else {
                                    ProgressView()
                                        .frame(width: 120, height: 120)
                                        .padding()
                                }
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
                
                // Rest of the form remains the same as in the previous implementation...
                
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
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snapshot, error in
            isLoading = false
            
            if let error = error {
                handleError("Error loading user data: \(error.localizedDescription)")
                return
            }
            
            if let snapshot = snapshot, let data = snapshot.data() {
                if let user = Models.User.fromDictionary(data, id: snapshot.documentID) {
                    self.userModel = user
                    
                    // Populate fields with user data
                    self.username = user.username
                    self.firstName = user.firstName
                    self.lastName = user.lastName
                    self.email = user.email
                    self.phoneNumber = user.phoneNumber
                    self.bio = user.bio
                    self.location = user.location
                    self.notificationsEnabled = user.notificationsEnabled
                    self.selectedLanguage = user.selectedLanguage
                    
                    // Reset changes flag
                    self.hasChanges = false
                }
            }
        }
    }
    
    // Save Settings
    private func saveSettings() {
        guard validateUsername() else { return }
        
        isLoading = true
        
        // Check if we have a user model
        guard let user = userModel, let userId = Auth.auth().currentUser?.uid else {
            handleError("User data not found")
            return
        }
        
        // Upload profile picture if changed
        if let newImage = profilePicture {
            print("DEBUG: User ID: \(userId)")
            print("DEBUG: Image size: \(newImage.size)")
            print("DEBUG: Image data size: \(newImage.jpegData(compressionQuality: 0.7)?.count ?? 0) bytes")
            
            ImageUploadService.shared.uploadProfilePicture(image: newImage, userId: userId) { result in
                switch result {
                case .success(let imageURL):
                    print("DEBUG: Image upload successful. URL: \(imageURL)")
                    updateUserData(user, profilePictureURL: imageURL)
                case .failure(let error):
                    print("DEBUG: Image upload failed.")
                    print("DEBUG: Error details: \(error)")
                    print("DEBUG: Error description: \(error.localizedDescription)")
                    handleError("Failed to upload profile picture: \(error.localizedDescription)")
                    isLoading = false
                }
            }
        } else {
            // Just update the user data without changing profile pic
            updateUserData(user, profilePictureURL: user.profilePicture)
        }
        
        // Update password if changed
        if !newPassword.isEmpty {
            updatePassword()
        }
    }
    
    // Update user data in Firestore
    private func updateUserData(_ user: Models.User, profilePictureURL: String?) {
        // Create new user with updated values
        var updatedUser = user
        updatedUser.username = username
        updatedUser.firstName = firstName
        updatedUser.lastName = lastName
        updatedUser.email = email
        updatedUser.phoneNumber = phoneNumber
        updatedUser.bio = bio
        updatedUser.location = location
        updatedUser.profilePicture = profilePictureURL
        updatedUser.notificationsEnabled = notificationsEnabled
        updatedUser.selectedLanguage = selectedLanguage
        
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
                self.userModel = updatedUser
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
