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
                                        AsyncImage(url: url) { image in
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
                    AddUsersView()
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
                fetchFriends()
            }
        }
    }
    
    private func fetchFriends() {
        guard let currentUser = authManager.currentUser else { return }
        
        isLoading = true
        
        let db = Firestore.firestore()
        // For each friend ID in the user's friends list, fetch the corresponding user details
        let friendIds = currentUser.friends
        
        if friendIds.isEmpty {
            isLoading = false
            return
        }
        
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
        guard let currentUser = authManager.currentUser, let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        for index in offsets {
            let friendToRemove = filteredFriends[index]
            let friendId = friendToRemove.id
            
            // Update current user's friends list
            db.collection("users").document(currentUserId).updateData([
                "friends": FieldValue.arrayRemove([friendId])
            ]) { error in
                if let error = error {
                    print("Error removing friend from current user: \(error.localizedDescription)")
                    return
                }
                
                // Update friend's friends list
                db.collection("users").document(friendId).updateData([
                    "friends": FieldValue.arrayRemove([currentUserId])
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
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                            .shadow(radius: 5)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.gray)
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

struct FriendsListView_Previews: PreviewProvider {
    static var previews: some View {
        FriendsListView()
            .environmentObject(AuthenticationManager())
    }
}
