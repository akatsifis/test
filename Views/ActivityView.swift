import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class ActivityViewModel: ObservableObject {
    @Published var currentUser: Models.User?
    @Published var friends: [Models.User] = []
    @Published var leagues: [EnhancedLeague] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    private var db = Firestore.firestore()
    
    // Maintain reference to listeners so they can be detached later
    private var userListener: ListenerRegistration?
    private var friendListeners: [String: ListenerRegistration] = [:]
    private var leagueListeners: [ListenerRegistration] = []
    
    init() {
        setupListeners()
    }
    
    deinit {
        // Clean up all listeners when ViewModel is deallocated
        removeAllListeners()
    }
    
    func setupListeners() {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.isLoading = false
            self.errorMessage = "You need to be logged in to view activity"
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        // Setup listener for current user
        setupUserListener(uid: uid)
    }
    
    private func setupUserListener(uid: String) {
        // Remove any existing user listener
        userListener?.remove()
        
        // Create new listener for user document
        userListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.isLoading = false
                    self.errorMessage = "Error loading your data: \(error.localizedDescription)"
                    return
                }
                
                guard let snapshot = snapshot, let data = snapshot.data() else {
                    self.isLoading = false
                    self.errorMessage = "User profile not found"
                    return
                }
                
                // Parse user data
                if let user = Models.User.fromDictionary(data, id: uid) {
                    self.currentUser = user
                    
                    // If user has friends, setup listeners for them
                    if !user.friends.isEmpty {
                        self.setupFriendListeners(friendIds: user.friends)
                    } else {
                        // No friends, just setup league listeners
                        self.setupLeagueListeners(uid: uid)
                    }
                } else {
                    self.isLoading = false
                    self.errorMessage = "Error parsing user data"
                }
            }
    }
    
    private func setupFriendListeners(friendIds: [String]) {
        // Remove any listeners for friends that are no longer in the list
        for (friendId, listener) in friendListeners {
            if !friendIds.contains(friendId) {
                listener.remove()
                friendListeners.removeValue(forKey: friendId)
            }
        }
        
        // Map of friend IDs to facilitate tracking which ones have been processed
        var newFriends: [String: Models.User] = [:]
        var pendingFriends = friendIds.count
        
        // Setup listeners for each friend
        for friendId in friendIds {
            // Skip if we already have a listener for this friend
            if friendListeners[friendId] != nil {
                pendingFriends -= 1
                continue
            }
            
            // Create a new listener for this friend
            let listener = db.collection("users").document(friendId)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    // Count this friend as processed
                    pendingFriends -= 1
                    
                    if let error = error {
                        print("Error fetching friend data: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let snapshot = snapshot, snapshot.exists, let data = snapshot.data() else {
                        print("Friend data not found for ID: \(friendId)")
                        return
                    }
                    
                    if let friend = Models.User.fromDictionary(data, id: friendId) {
                        newFriends[friendId] = friend
                    }
                    
                    // If all friends have been processed, update the friends list
                    if pendingFriends <= 0 {
                        // Build complete list of friends
                        var allFriends: [Models.User] = []
                        
                        // First add existing friends that are still in the list
                        for friend in self.friends {
                            if friendIds.contains(friend.id) {
                                // Use updated version if available
                                if let updatedFriend = newFriends[friend.id] {
                                    allFriends.append(updatedFriend)
                                    newFriends.removeValue(forKey: friend.id)
                                } else {
                                    allFriends.append(friend)
                                }
                            }
                        }
                        
                        // Then add any new friends
                        allFriends.append(contentsOf: newFriends.values)
                        
                        // Update the friends list
                        self.friends = allFriends
                        
                        // Setup league listeners after friends are loaded
                        self.setupLeagueListeners(uid: Auth.auth().currentUser?.uid ?? "")
                    }
                }
            
            // Store the listener
            friendListeners[friendId] = listener
        }
        
        // If no friends to process, setup league listeners directly
        if friendIds.isEmpty {
            setupLeagueListeners(uid: Auth.auth().currentUser?.uid ?? "")
        }
    }
    
    private func setupLeagueListeners(uid: String) {
        // Remove any existing league listeners
        for listener in leagueListeners {
            listener.remove()
        }
        leagueListeners = []
        
        // Setup listener for leagues where user is host
        let hostLeagueListener = db.collection("leagues")
            .whereField("hostUserId", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching hosted leagues: \(error.localizedDescription)")
                    return
                }
                
                var fetchedLeagues: [EnhancedLeague] = []
                
                if let documents = snapshot?.documents {
                    for document in documents {
                        if let league = EnhancedLeague.fromDictionary(document.data(), id: document.documentID) {
                            fetchedLeagues.append(league)
                        }
                    }
                }
                
                // Update leagues (we'll merge with member leagues later)
                self.updateLeagues(hostLeagues: fetchedLeagues)
            }
        
        leagueListeners.append(hostLeagueListener)
        
        // Setup listener for leagues where user is a member
        let memberLeagueListener = db.collection("leagues")
            .whereField("members", arrayContains: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching member leagues: \(error.localizedDescription)")
                    return
                }
                
                var fetchedLeagues: [EnhancedLeague] = []
                
                if let documents = snapshot?.documents {
                    for document in documents {
                        if let league = EnhancedLeague.fromDictionary(document.data(), id: document.documentID) {
                            fetchedLeagues.append(league)
                        }
                    }
                }
                
                // Update leagues (we'll merge with host leagues)
                self.updateLeagues(memberLeagues: fetchedLeagues)
            }
        
        leagueListeners.append(memberLeagueListener)
        
        // We're done loading
        self.isLoading = false
    }
    
    // Property to store leagues where user is host
    private var hostLeagues: [EnhancedLeague] = []
    
    // Property to store leagues where user is member
    private var memberLeagues: [EnhancedLeague] = []
    
    // Method to update leagues based on host leagues
    private func updateLeagues(hostLeagues: [EnhancedLeague]? = nil, memberLeagues: [EnhancedLeague]? = nil) {
        if let hostLeagues = hostLeagues {
            self.hostLeagues = hostLeagues
        }
        
        if let memberLeagues = memberLeagues {
            self.memberLeagues = memberLeagues
        }
        
        // Combine host and member leagues, avoiding duplicates
        var allLeagues = self.hostLeagues
        
        for league in self.memberLeagues {
            if !allLeagues.contains(where: { $0.id == league.id }) {
                allLeagues.append(league)
            }
        }
        
        // Update the published leagues property
        self.leagues = allLeagues
    }
    
    // Method to remove all listeners
    func removeAllListeners() {
        userListener?.remove()
        
        for (_, listener) in friendListeners {
            listener.remove()
        }
        friendListeners.removeAll()
        
        for listener in leagueListeners {
            listener.remove()
        }
        leagueListeners.removeAll()
    }
}

// Updated ActivityView to use the view model
struct ActivityView: View {
    @StateObject private var viewModel = ActivityViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading activity data...")
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                            .padding()
                        
                        Text(error)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button("Try Again") {
                            viewModel.setupListeners()
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
                        if let user = viewModel.currentUser {
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
                        if !viewModel.friends.isEmpty {
                            Section(header: Text("Friends' Activity").font(.headline)) {
                                ForEach(viewModel.friends) { friend in
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
                        
                        // League Activity Section
                        if !viewModel.leagues.isEmpty {
                            Section(header: Text("League Activity").font(.headline)) {
                                ForEach(viewModel.leagues) { league in
                                    NavigationLink(destination: EnhancedLeagueDetailView(
                                        league: league,
                                        isHost: league.hostUserId == Auth.auth().currentUser?.uid
                                    )) {
                                        LeagueActivityCard(league: league)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        } else {
                            Section(header: Text("League Activity").font(.headline)) {
                                VStack(spacing: 12) {
                                    Text("You're not part of any leagues yet")
                                        .foregroundColor(.gray)
                                        .italic()
                                    
                                    NavigationLink(destination: LeagueDashboardView()) {
                                        Text("Join a League")
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 8)
                                            .background(Color.green)
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
                        // Reinitialize listeners on manual refresh
                        viewModel.removeAllListeners()
                        viewModel.setupListeners()
                    }
                }
            }
            .navigationTitle("Activity Feed")
            .onAppear {
                // Setup listeners when view appears
                viewModel.setupListeners()
            }
            .onDisappear {
                // Clean up listeners when view disappears
                viewModel.removeAllListeners()
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

struct LeagueActivityCard: View {
    let league: EnhancedLeague
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(league.name)
                        .font(.headline)
                    
                    Text(league.course)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("\(league.schedule) on \(league.playDay.rawValue)")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.trailing)
            }
            
            Divider()
            
            HStack {
                if let nextDate = league.nextScheduledDate {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Play:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(formatDate(nextDate.dateValue()))
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Members:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("\(league.members.count + 1)") // +1 for host
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
