//
//  AddUsersView.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/5/25.
//


//
//  AddUsersView.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/5/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct AddUsersView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var searchText = ""
    @State private var searchResults: [Models.User] = []
    @State private var isSearching = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search by username, email, or phone", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .onChange(of: searchText) { value in
                if value.count >= 3 {
                    searchUsers()
                }
            }
            
            if isSearching {
                ProgressView("Searching...")
                    .padding()
            } else if searchResults.isEmpty && !searchText.isEmpty {
                Text("No users found")
                    .foregroundColor(.gray)
                    .padding(.top, 20)
            } else {
                List {
                    ForEach(searchResults) { user in
                        UserRowView(user: user, onSendRequest: { sendFriendRequest(to: user) })
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            
            Spacer()
        }
        .navigationTitle("Add Friends")
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Friend Request"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func searchUsers() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        searchResults = []
        
        UserService.shared.searchUsers(query: searchText) { result in
            DispatchQueue.main.async {
                self.isSearching = false
                
                switch result {
                case .success(let users):
                    // Filter out current user and existing friends
                    self.searchResults = users.filter { user in
                        guard let currentUser = self.authManager.currentUser else { return true }
                        
                        // Filter out current user
                        if user.id == currentUser.id {
                            return false
                        }
                        
                        // Filter out existing friends
                        return !currentUser.friends.contains(user.id)
                    }
                case .failure(let error):
                    self.alertMessage = "Error searching users: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func sendFriendRequest(to user: Models.User) {
        guard let currentUser = authManager.currentUser, let currentUserId = Auth.auth().currentUser?.uid else {
            alertMessage = "You must be logged in to send friend requests"
            showingAlert = true
            return
        }
        
        let db = Firestore.firestore()
        
        // Create a friend request
        let requestData: [String: Any] = [
            "fromUserId": currentUserId,
            "toUserId": user.id,
            "status": "pending",
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        db.collection("friendRequests").addDocument(data: requestData) { error in
            if let error = error {
                alertMessage = "Failed to send friend request: \(error.localizedDescription)"
                showingAlert = true
            } else {
                alertMessage = "Friend request sent to \(user.username)"
                showingAlert = true
            }
        }
    }
}

struct UserRowView: View {
    let user: Models.User
    let onSendRequest: () -> Void
    
    var body: some View {
        HStack {
            if let profilePicture = user.profilePicture, let url = URL(string: profilePicture) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading) {
                Text(user.username)
                    .font(.headline)
                
                if !user.firstName.isEmpty || !user.lastName.isEmpty {
                    Text("\(user.firstName) \(user.lastName)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                if !user.phoneNumber.isEmpty {
                    Text(user.phoneNumber)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Button(action: onSendRequest) {
                Text("Add")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddUsersView_Previews: PreviewProvider {
    static var previews: some View {
        AddUsersView()
            .environmentObject(AuthenticationManager())
    }
}