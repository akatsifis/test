//
//  ProfileView.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/5/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingEditView = false
    @State private var userModel: Models.User?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Header
                VStack {
                    // Profile picture
                    if let user = userModel, let profilePicture = user.profilePicture,
                       let url = URL(string: profilePicture) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                                    .shadow(radius: 5)
                            } else if phase.error != nil {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                                    .foregroundColor(.gray)
                            } else {
                                ProgressView()
                                    .frame(width: 120, height: 120)
                            }
                        }
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.gray)
                    }
                    
                    // Username and basic info
                    if let user = userModel {
                        Text(user.username)
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.top, 8)
                        
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        if !user.bio.isEmpty {
                            Text(user.bio)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.top, 4)
                        }
                    }
                    
                    // Edit profile button
                    Button(action: {
                        showingEditView = true
                    }) {
                        Text("Edit Profile")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 20)
                            .background(Color.blue)
                            .cornerRadius(20)
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 3)
                .padding(.horizontal)
                
                // Stats Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Stats")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    if let user = userModel {
                        // Total Rounds
                        StatCardView(
                            icon: "flag.fill",
                            title: "Total Rounds",
                            value: "\(user.scores.count)",
                            color: .green
                        )
                        
                        // Best Score
                        StatCardView(
                            icon: "trophy.fill",
                            title: "Best Score",
                            value: getBestScore(user),
                            color: .orange
                        )
                        
                        // Total Steps
                        StatCardView(
                            icon: "figure.walk",
                            title: "Total Steps",
                            value: getFormattedSteps(user),
                            color: .blue
                        )
                    }
                }
                .padding(.top)
                
                // Recent Rounds
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Rounds")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    if let user = userModel, !user.scores.isEmpty {
                        ForEach(user.scores.sorted(by: { $0.date > $1.date }).prefix(3), id: \.id) { score in
                            RoundCardView(score: score)
                        }
                        
                        Button(action: {
                            // Navigate to full history view
                        }) {
                            Text("View All Rounds")
                                .font(.headline)
                                .foregroundColor(.blue)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    } else {
                        Text("No rounds recorded yet")
                            .foregroundColor(.gray)
                            .italic()
                            .padding()
                    }
                }
                .padding(.top)
                
                // Log out button
                Button(action: {
                    do {
                        try Auth.auth().signOut()
                        // Handle any UI updates needed
                    } catch {
                        print("Error signing out: \(error.localizedDescription)")
                    }
                }) {
                    Text("Log Out")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $showingEditView) {
            if let user = userModel {
                ProfileEditView(userModel: user)
            }
        }
        .onAppear(perform: fetchUserData)
    }
    
    private func fetchUserData() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }
            
            if let snapshot = snapshot, let data = snapshot.data() {
                self.userModel = Models.User.fromDictionary(data, id: snapshot.documentID)
            }
        }
    }
    
    // Helper function to get best score
    private func getBestScore(_ user: Models.User) -> String {
        if user.scores.isEmpty {
            return "N/A"
        }
        
        if let bestScore = user.scores.min(by: { $0.score < $1.score }) {
            return "\(bestScore.score) at \(bestScore.course)"
        }
        
        return "N/A"
    }
    
    // Helper function to format total steps
    private func getFormattedSteps(_ user: Models.User) -> String {
        let totalSteps = user.scores.compactMap { $0.steps }.reduce(0, +)
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        if let formattedSteps = formatter.string(from: NSNumber(value: totalSteps)) {
            return formattedSteps
        }
        
        return "\(totalSteps)"
    }
}

struct StatCardView: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

struct RoundCardView: View {
    let score: Models.User.Score
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(score.course)
                    .font(.headline)
                
                Text(formattedDate(score.date))
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(score.score)")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(score.holesPlayed)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct ProfileEditView: View {
    @Environment(\.presentationMode) var presentationMode
    var userModel: Models.User
    
    @State private var username: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    @State private var profileImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                // Profile Image Section
                Section {
                    VStack {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                        } else if let profilePicture = userModel.profilePicture,
                                  let url = URL(string: profilePicture) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                                } else if phase.error != nil {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 120, height: 120)
                                        .foregroundColor(.gray)
                                } else {
                                    ProgressView()
                                        .frame(width: 120, height: 120)
                                }
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundColor(.gray)
                        }
                        
                        Button("Change Photo") {
                            showImagePicker = true
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                // Basic Info Section
                Section(header: Text("Basic Information")) {
                    TextField("Username", text: $username)
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                }
                
                // Bio Section
                Section(header: Text("About You")) {
                    TextEditor(text: $bio)
                        .frame(height: 100)
                    
                    TextField("Location", text: $location)
                }
                
                // Save Button
                Section {
                    Button(action: saveChanges) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(isLoading ? Color.gray : Color.blue)
                    .cornerRadius(10)
                    .disabled(isLoading)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear(perform: loadUserData)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $profileImage)
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Profile Update"), message: Text(alertMessage), dismissButton: .default(Text("OK")) {
                    if alertMessage.contains("Success") {
                        presentationMode.wrappedValue.dismiss()
                    }
                })
            }
        }
    }
    
    private func loadUserData() {
        username = userModel.username
        firstName = userModel.firstName
        lastName = userModel.lastName
        bio = userModel.bio
        location = userModel.location
    }
    
    private func saveChanges() {
        isLoading = true
        
        // First handle profile image update if needed
        if let newImage = profileImage {
            UserService.shared.updateProfilePicture(image: newImage) { result in
                switch result {
                case .success(let imageURL):
                    // Now update the rest of user info
                    updateUserInfo(profilePictureURL: imageURL)
                    
                case .failure(let error):
                    isLoading = false
                    alertMessage = "Failed to update profile picture: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        } else {
            // Just update user info
            updateUserInfo(profilePictureURL: userModel.profilePicture)
        }
    }
    
    private func updateUserInfo(profilePictureURL: String?) {
        // Create updated user model
        var updatedUser = userModel
        updatedUser.username = username
        updatedUser.firstName = firstName
        updatedUser.lastName = lastName
        updatedUser.bio = bio
        updatedUser.location = location
        updatedUser.profilePicture = profilePictureURL
        
        // Save to Firestore
        UserService.shared.updateUser(userData: updatedUser) { result in
            isLoading = false
            
            switch result {
            case .success:
                alertMessage = "Profile updated successfully!"
                showAlert = true
                
            case .failure(let error):
                alertMessage = "Failed to update profile: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthenticationManager())
    }
}
