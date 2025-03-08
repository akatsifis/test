//
//  ActivityView.swift
//  Aldo
//
//  Created by Andrew Katsifis on 6/12/24.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ActivityView: View {
    @State private var currentUser: Models.User?
    @State private var friends: [Models.User] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView("Loading activity data...")
                } else if let error = errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                            .padding()
                        
                        Text(error)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button("Try Again") {
                            errorMessage = nil
                            fetchData()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                } else {
                    List {
                        // Current User Activity Section
                        if let user = currentUser {
                            Section(header: Text("Your Activity").font(.headline)) {
                                
                                // User summary card
                                UserSummaryCard(user: user)
                                    .padding(.vertical, 8)
                                
                                // User scores
                                if user.scores.isEmpty {
                                    Text("You haven't recorded any rounds yet")
                                        .foregroundColor(.gray)
                                        .italic()
                                        .padding(.vertical, 8)
                                } else {
                                    ForEach(user.scores.sorted(by: { $0.date > $1.date })) { score in
                                        ScoreCard(user: user, score: score)
                                    }
                                }
                            }
                        }
                        
                        // Friends Activity Section
                        if !friends.isEmpty {
                            Section(header: Text("Friends' Activity").font(.headline)) {
                                ForEach(friends) { friend in
                                    // Only show if friend has scores
                                    if !friend.scores.isEmpty {
                                        VStack(alignment: .leading) {
                                            // Friend summary
                                            UserSummaryCard(user: friend)
                                                .padding(.vertical, 4)
                                            
                                            // Friends' most recent scores (up to 3)
                                            ForEach(friend.scores.sorted(by: { $0.date > $1.date }).prefix(3), id: \.id) { score in
                                                ScoreCard(user: friend, score: score)
                                                    .padding(.vertical, 4)
                                            }
                                            
                                            if friend.scores.count > 3 {
                                                Button(action: {
                                                    // Navigate to friend's detail view to see all scores
                                                }) {
                                                    Text("See all \(friend.scores.count) rounds")
                                                        .font(.caption)
                                                        .foregroundColor(.blue)
                                                }
                                                .padding(.vertical, 4)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                        } else {
                            Section(header: Text("Friends' Activity").font(.headline)) {
                                VStack(spacing: 12) {
                                    Text("You haven't added any friends yet")
                                        .foregroundColor(.gray)
                                        .italic()
                                    
                                    NavigationLink(destination: FriendsListView()) {
                                        Text("Find Friends")
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 8)
                                            .background(Color.blue)
                                            .cornerRadius(8)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .refreshable {
                        await refreshData()
                    }
                }
            }
            .navigationTitle("Activity Feed")
            .onAppear(perform: fetchData)
        }
    }
    
    private func fetchData() {
        isLoading = true
        errorMessage = nil
        
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            errorMessage = "You need to be logged in to view activity"
            return
        }
        
        let db = Firestore.firestore()
        
        // Fetch current user
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Error loading your data: \(error.localizedDescription)"
                }
                return
            }
            
            guard let snapshot = snapshot, let data = snapshot.data() else {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "User profile not found"
                }
                return
            }
            
            // Parse user data
            if let user = Models.User.fromDictionary(data, id: uid) {
                DispatchQueue.main.async {
                    self.currentUser = user
                }
                
                // If user has friends, fetch them
                if !user.friends.isEmpty {
                    fetchFriends(friendIds: user.friends)
                } else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Error parsing user data"
                }
            }
        }
    }
    
    private func fetchFriends(friendIds: [String]) {
        let db = Firestore.firestore()
        let dispatchGroup = DispatchGroup()
        var fetchedFriends: [Models.User] = []
        var fetchErrors: [String] = []
        
        for friendId in friendIds {
            dispatchGroup.enter()
            
            db.collection("users").document(friendId).getDocument { snapshot, error in
                defer { dispatchGroup.leave() }
                
                if let error = error {
                    fetchErrors.append("Error fetching friend data: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists, let data = snapshot.data() else {
                    fetchErrors.append("Friend data not found for ID: \(friendId)")
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
            
            // If we had errors but still got some friends, we don't show the error
            if fetchedFriends.isEmpty && !fetchErrors.isEmpty {
                self.errorMessage = fetchErrors.first
            }
        }
    }
    
    private func refreshData() async {
        // Create a task that fetches the data and can be awaited
        return await withCheckedContinuation { continuation in
            fetchData()
            // Always continue after a delay to ensure UI updates properly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                continuation.resume()
            }
        }
    }
}

// MARK: - Helper Views

struct UserSummaryCard: View {
    let user: Models.User
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture
            if let profilePicture = user.profilePicture, let url = URL(string: profilePicture) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else if phase.error != nil {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.gray)
                    } else {
                        ProgressView()
                            .frame(width: 60, height: 60)
                    }
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundColor(.gray)
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.username)
                    .font(.headline)
                
                Text("\(user.firstName) \(user.lastName)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text("Total Rounds: \(user.scores.count)")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                // Total steps
                let totalSteps = user.scores.compactMap { $0.steps }.reduce(0, +)
                if totalSteps > 0 {
                    Text("Total Steps: \(totalSteps)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
        }
    }
}

struct ScoreCard: View {
    let user: Models.User
    let score: Models.User.Score
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Course and date
            HStack {
                Text(score.course)
                    .font(.headline)
                
                Spacer()
                
                Text(formatDate(score.date))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Score and holes
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Score:")
                            .font(.subheadline)
                        
                        Text("\(score.score)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    Text(score.holesPlayed)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Workout stats if available
                if let steps = score.steps, steps > 0 {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack {
                            Image(systemName: "figure.walk")
                                .font(.caption)
                            
                            Text("\(steps) steps")
                                .font(.subheadline)
                        }
                        .foregroundColor(.green)
                        
                        if let distance = score.distance, distance > 0 {
                            Text(String(format: "%.1f miles", distance))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct ActivityView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityView()
    }
}
