import SwiftUI
import Firebase
import FirebaseFirestore

struct EnhancedLeagueDetailView: View {
    let league: EnhancedLeague
    let isHost: Bool
    
    @State private var selectedTab = 0
    @State private var scheduledDates: [LeagueDate] = []
    @State private var standings: [LeagueStanding] = []
    @State private var members: [Models.User] = []
    @State private var rounds: [LeagueRound] = []
    @State private var isLoading = true
    @State private var showEditLeague = false
    
    // Player detail view state
    @State private var selectedPlayer: LeagueStanding? = nil
    @State private var showPlayerDetail = false
    
    var body: some View {
        VStack(spacing: 0) {
            leagueHeader
            
            // Tab selector
            Picker("View", selection: $selectedTab) {
                Text("Schedule").tag(0)
                Text("Standings").tag(1)
                Text("Rounds").tag(2)
                Text("Chat").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Tab content
            TabView(selection: $selectedTab) {
                // Schedule tab
                scheduleTab
                    .tag(0)
                
                // Standings tab
                standingsTab
                    .tag(1)
                
                // Rounds tab
                roundsTab
                    .tag(2)
                
                // Chat tab
                LeagueChatView(leagueId: league.id, leagueName: league.name)
                    .tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationTitle(league.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing:
            Button(action: {
                showEditLeague = true
            }) {
                Text("Edit League")
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .opacity(isHost ? 1.0 : 0.0) // Only visible to host
        )
        .onAppear {
            fetchLeagueData()
        }
        .sheet(isPresented: $showEditLeague) {
            EnhancedLeagueEditView(league: league)
        }
        .sheet(item: $selectedPlayer) { player in
            PlayerDetailView(playerId: player.id, playerName: player.username, leagueId: league.id)
        }
    }
    
    // MARK: - UI Components
    
    private var leagueHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(league.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(league.course)
                        .font(.subheadline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(league.schedule) on \(league.playDay.rawValue)s")
                        .font(.subheadline)
                    
                    if let nextDate = league.nextScheduledDate {
                        Text("Next: \(formatDate(nextDate.dateValue()))")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var scheduleTab: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading schedule...")
                    .padding()
            } else if scheduledDates.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No scheduled dates yet")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    if isHost {
                        Button(action: {
                            generateSchedule()
                        }) {
                            Text("Generate Schedule")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.top, 40)
            } else {
                VStack(alignment: .leading, spacing: 15) {
                    ForEach(scheduledDates) { date in
                        ScheduleDateCard(date: date, league: league)
                    }
                }
                .padding()
            }
        }
    }
    
    private var standingsTab: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading standings...")
                    .padding()
            } else if standings.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "trophy")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No standings available yet")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("Complete some rounds to see standings")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("League Standings")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Standings header
                    HStack {
                        Text("Rank")
                            .fontWeight(.bold)
                            .frame(width: 50, alignment: .center)
                        
                        Text("Player")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Avg")
                            .fontWeight(.bold)
                            .frame(width: 60, alignment: .center)
                        
                        Text("Rounds")
                            .fontWeight(.bold)
                            .frame(width: 60, alignment: .center)
                    }
                    .font(.caption)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    
                    // Player standings
                    ForEach(Array(standings.enumerated()), id: \.element.id) { index, player in
                        Button(action: {
                            selectedPlayer = player
                        }) {
                            HStack {
                                Text("\(index + 1)")
                                    .font(.subheadline)
                                    .frame(width: 50, alignment: .center)
                                
                                HStack {
                                    if let profilePic = player.profilePicture, let url = URL(string: profilePic) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 30, height: 30)
                                                    .clipShape(Circle())
                                            } else {
                                                Image(systemName: "person.circle")
                                                    .resizable()
                                                    .frame(width: 30, height: 30)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    } else {
                                        Image(systemName: "person.circle")
                                            .resizable()
                                            .frame(width: 30, height: 30)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Text(player.username)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text(String(format: "%.1f", player.averageScore))
                                    .font(.subheadline)
                                    .frame(width: 60, alignment: .center)
                                
                                Text("\(player.roundsPlayed)")
                                    .font(.subheadline)
                                    .frame(width: 60, alignment: .center)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                            .background(index % 2 == 0 ? Color(.systemBackground) : Color(.systemGray6))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(radius: 1)
                .padding()
            }
        }
    }
    
    private var roundsTab: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading rounds...")
                    .padding()
            } else if rounds.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "figure.golf")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No rounds recorded yet")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        // Submit a round
                    }) {
                        Text("Submit Score")
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.top, 40)
            } else {
                VStack(alignment: .leading, spacing: 15) {
                    ForEach(rounds, id: \.id) { round in
                        RoundCard(round: round, leagueId: league.id)
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Data Functions
    
    private func fetchLeagueData() {
        isLoading = true
        
        // Create dispatch group to track multiple async tasks
        let group = DispatchGroup()
        
        // 1. Fetch scheduled dates
        group.enter()
        fetchScheduledDates { success in
            group.leave()
        }
        
        // 2. Fetch standings
        group.enter()
        fetchStandings { success in
            group.leave()
        }
        
        // 3. Fetch members
        group.enter()
        fetchMembers { success in
            group.leave()
        }
        
        // 4. Fetch rounds
        group.enter()
        fetchRounds { success in
            group.leave()
        }
        
        // When all tasks are complete
        group.notify(queue: .main) {
            self.isLoading = false
        }
    }
    
    private func fetchScheduledDates(completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        db.collection("leagues").document(league.id).collection("dates")
            .order(by: "date")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching scheduled dates: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                var dates: [LeagueDate] = []
                
                if let documents = snapshot?.documents, !documents.isEmpty {
                    for document in documents {
                        let data = document.data()
                        
                        if let timestamp = data["date"] as? Timestamp,
                           let location = data["location"] as? String {
                            let confirmedCount = data["confirmedCount"] as? Int ?? 0
                            
                            let leagueDate = LeagueDate(
                                id: document.documentID,
                                date: timestamp.dateValue(),
                                location: location,
                                confirmedCount: confirmedCount
                            )
                            
                            dates.append(leagueDate)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.scheduledDates = dates
                    completion(true)
                }
            }
    }
    
    private func fetchStandings(completion: @escaping (Bool) -> Void) {
        EnhancedLeagueService.shared.fetchLeagueStandings(leagueId: league.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fetchedStandings):
                    self.standings = fetchedStandings
                    completion(true)
                case .failure(let error):
                    print("Error fetching standings: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    private func fetchMembers(completion: @escaping (Bool) -> Void) {
        guard !league.members.isEmpty else {
            completion(true)
            return
        }
        
        let db = Firestore.firestore()
        let dispatchGroup = DispatchGroup()
        var fetchedMembers: [Models.User] = []
        
        for memberId in league.members {
            dispatchGroup.enter()
            
            db.collection("users").document(memberId).getDocument { snapshot, error in
                defer { dispatchGroup.leave() }
                
                if let error = error {
                    print("Error fetching member data: \(error.localizedDescription)")
                    return
                }
                
                if let snapshot = snapshot, snapshot.exists, let data = snapshot.data() {
                    if let member = Models.User.fromDictionary(data, id: snapshot.documentID) {
                        fetchedMembers.append(member)
                    }
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.members = fetchedMembers
            completion(true)
        }
    }
    
    private func fetchRounds(completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        db.collection("leagues").document(league.id).collection("rounds")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching rounds: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                var fetchedRounds: [LeagueRound] = []
                
                if let documents = snapshot?.documents {
                    for doc in documents {
                        let data = doc.data()
                        let number = data["number"] as? Int ?? 0
                        let score = data["score"] as? Int ?? 0
                        let createdAt = data["createdAt"] as? Timestamp ?? Timestamp(date: Date())
                        
                        let round = LeagueRound(
                            id: doc.documentID,
                            number: number,
                            score: score,
                            createdAt: createdAt
                        )
                        
                        fetchedRounds.append(round)
                    }
                }
                
                DispatchQueue.main.async {
                    self.rounds = fetchedRounds
                    completion(true)
                }
            }
    }
    
    private func generateSchedule() {
        // Calculate dates based on frequency and day of week
        var scheduleDates: [Date] = []
        let calendar = Calendar.current
        
        // Start with current date
        var currentDate = Date()
        
        // Find next occurrence of play day
        let currentWeekday = calendar.component(.weekday, from: currentDate)
        let targetWeekday = league.playDay.toWeekdayInt()
        var daysToAdd = targetWeekday - currentWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7 // Move to next week
        }
        
        currentDate = calendar.date(byAdding: .day, value: daysToAdd, to: currentDate)!
        
        // Generate 12 dates
        for _ in 0..<12 {
            scheduleDates.append(currentDate)
            
            // Add days based on frequency
            switch league.schedule {
            case "Weekly":
                currentDate = calendar.date(byAdding: .day, value: 7, to: currentDate)!
            case "Every 2 Weeks", "Bi-weekly":
                currentDate = calendar.date(byAdding: .day, value: 14, to: currentDate)!
            case "Monthly":
                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate)!
            default:
                currentDate = calendar.date(byAdding: .day, value: 7, to: currentDate)!
            }
        }
        
        // Save dates to Firestore
        let db = Firestore.firestore()
        let batch = db.batch()
        
        for date in scheduleDates {
            let dateRef = db.collection("leagues").document(league.id).collection("dates").document()
            
            let dateData: [String: Any] = [
                "date": Timestamp(date: date),
                "location": league.course,
                "confirmedCount": 0,
                "maybeCount": 0,
                "declinedCount": 0
            ]
            
            batch.setData(dateData, forDocument: dateRef)
        }
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                print("Error creating schedule: \(error.localizedDescription)")
            } else {
                // Refresh scheduled dates
                fetchScheduledDates { _ in }
                
                // Update the next scheduled date on the league
                if let firstDate = scheduleDates.first {
                    db.collection("leagues").document(league.id).updateData([
                        "nextScheduledDate": Timestamp(date: firstDate)
                    ])
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
