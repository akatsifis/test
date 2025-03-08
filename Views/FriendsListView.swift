//
//  FriendsListView.swift
//  Aldo
//
//  Created by Andrew Katsifis on 6/25/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct FriendsListView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showAddUsers = false
    @State private var friends: [Models.User] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var currentUser: Models.User?
    
    var filteredFriends: [Models.User] {
        if searchText.isEmpty {
            return friends
        } else {
            return friends.filter { friend in
                friend.username.localizedCaseInsensitiveContains(searchText) ||
                friend.phoneNumber.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search friends", text: $searchText)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                if isLoading {
                    ProgressView("Loading friends...")
                        .padding()
                } else if friends.isEmpty {
                    VStack(spacing: 20) {
                        Text("You don't have any friends yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            showAddUsers = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Add Friends")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.top, 50)
                } else {
                    List {
                        ForEach(filteredFriends) { friend in
                            NavigationLink(destination: FriendDetailView(friend: friend)) {
                                HStack {
                                    if let profilePicture = friend.profilePicture, let url = URL(string: profilePicture) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 50, height: 50)
                                                    .clipShape(Circle())
                                            } else if phase.error != nil {
                                                Image(systemName: "person.circle.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 50, height: 50)
                                                    .foregroundColor(.gray)
                                            } else {
                                                ProgressView()
                                                    .frame(width: 50, height: 50)
                                            }
                                        }
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 50, height: 50)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text(friend.username)
                                            .font(.headline)
                                        Text(friend.phoneNumber)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: removeFriend)
                    }
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddUsers = true
                    }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAddUsers) {
                NavigationView {
                    UserSearchView()
                        .navigationTitle("Add Friends")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") {
                                    showAddUsers = false
                                }
                            }
                        }
                }
            }
            .onAppear {
                fetchCurrentUser()
            }
        }
    }
    
    private func fetchCurrentUser() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching current user: \(error.localizedDescription)")
                isLoading = false
                return
            }
            
            if let snapshot = snapshot, let data = snapshot.data() {
                self.currentUser = Models.User.fromDictionary(data, id: snapshot.documentID)
                
                if let currentUser = self.currentUser {
                    fetchFriends(friendIds: currentUser.friends)
                } else {
                    isLoading = false
                }
            } else {
                isLoading = false
            }
        }
    }
    
    private func fetchFriends(friendIds: [String]) {
        if friendIds.isEmpty {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        let dispatchGroup = DispatchGroup()
        var fetchedFriends: [Models.User] = []
        
        for friendId in friendIds {
            dispatchGroup.enter()
            
            db.collection("users").document(friendId).getDocument { snapshot, error in
                defer { dispatchGroup.leave() }
                
                if let error = error {
                    print("Error fetching friend data: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists, let data = snapshot.data() else {
                    print("Friend document doesn't exist for ID: \(friendId)")
                    return
                }
                
                if let friend = Models.User.fromDictionary(data, id: friendId) {
                    fetchedFriends.append(friend)
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.friends = fetchedFriends
            self.isLoading = false
        }
    }
    
    private func removeFriend(at offsets: IndexSet) {
        guard let currentUser = currentUser, let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        for index in offsets {
            let friendToRemove = filteredFriends[index]
            let friendId = friendToRemove.id
            
            // Update current user's friends list
            db.collection("users").document(userId).updateData([
                "friends": FieldValue.arrayRemove([friendId])
            ]) { error in
                if let error = error {
                    print("Error removing friend from current user: \(error.localizedDescription)")
                    return
                }
                
                // Update friend's friends list
                db.collection("users").document(friendId).updateData([
                    "friends": FieldValue.arrayRemove([userId])
                ]) { error in
                    if let error = error {
                        print("Error removing current user from friend: \(error.localizedDescription)")
                    }
                }
            }
            
            // Update local data
            if let indexInMainList = friends.firstIndex(where: { $0.id == friendId }) {
                friends.remove(at: indexInMainList)
            }
        }
    }
}

struct FriendDetailView: View {
    let friend: Models.User
    @State private var showingScores = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 20) {
                // Profile picture
                if let profilePicture = friend.profilePicture, let url = URL(string: profilePicture) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
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
                
                // User info
                Text(friend.username)
                    .font(.title)
                    .fontWeight(.bold)
                
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.gray)
                    Text(friend.email)
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.gray)
                    Text(friend.phoneNumber.isEmpty ? "No phone number" : friend.phoneNumber)
                        .foregroundColor(.gray)
                }
                
                if !friend.bio.isEmpty {
                    VStack(alignment: .leading) {
                        Text("About")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        Text(friend.bio)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // Action buttons
                Button(action: {
                    showingScores.toggle()
                }) {
                    HStack {
                        Image(systemName: "list.bullet.clipboard")
                        Text("View Scores")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                Button(action: {
                    // Implement message functionality
                }) {
                    HStack {
                        Image(systemName: "message.fill")
                        Text("Message")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Friend Details")
        .sheet(isPresented: $showingScores) {
            ScoresListView(user: friend)
        }
    }
}

struct ScoresListView: View {
    let user: Models.User
    
    var body: some View {
        NavigationView {
            List {
                if user.scores.isEmpty {
                    Text("No scores recorded")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ForEach(user.scores.sorted(by: { $0.date > $1.date })) { score in
                        ScoreRow(score: score)
                    }
                }
            }
            .navigationTitle("\(user.username)'s Scores")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Close sheet
                    }
                }
            }
        }
    }
}

struct ScoreRow: View {
    let score: Models.User.Score
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(score.course)
                    .font(.headline)
                Spacer()
                Text("\(score.score)")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            HStack {
                Text(dateFormatter.string(from: score.date))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
                Text(score.holesPlayed)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            if let steps = score.steps, steps > 0 {
                HStack {
                    Image(systemName: "figure.walk")
                    Text("\(steps) steps")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

// This is a replacement for AddUsersView
struct UserSearchView: View {
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
                    guard let currentUserId = Auth.auth().currentUser?.uid else {
                        self.searchResults = users
                        return
                    }
                    
                    let db = Firestore.firestore()
                    db.collection("users").document(currentUserId).getDocument { snapshot, error in
                        if let error = error {
                            print("Error fetching current user: \(error.localizedDescription)")
                            self.searchResults = users.filter { $0.id != currentUserId }
                            return
                        }
                        
                        if let data = snapshot?.data(), let userFriends = data["friends"] as? [String] {
                            self.searchResults = users.filter { user in
                                user.id != currentUserId && !userFriends.contains(user.id)
                            }
                        } else {
                            self.searchResults = users.filter { $0.id != currentUserId }
                        }
                    }
                    
                case .failure(let error):
                    self.alertMessage = "Error searching users: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func sendFriendRequest(to user: Models.User) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
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
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    } else if phase.error != nil {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.gray)
                    } else {
                        ProgressView()
                            .frame(width: 50, height: 50)
                    }
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

struct FriendsListView_Previews: PreviewProvider {
    static var previews: some View {
        FriendsListView()
            .environmentObject(AuthenticationManager())
    }
}
