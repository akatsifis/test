import SwiftUI
import Firebase
import FirebaseFirestore
import PhotosUI

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
                if isHost {
                    Text("Manage").tag(3)
                }
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
                
                // Manage tab (host only)
                if isHost {
                    manageTab
                        .tag(3)
                }
                
                // Chat tab
                chatTab
                    .tag(4)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        
        Picker("View", selection: $selectedTab) {
            Text("Schedule").tag(0)
            Text("Chat").tag(1)
            Text("Standings").tag(2)
            Text("Rounds").tag(3)
            if isHost {
                Text("Manage").tag(4)
            }
        }
        .navigationTitle(league.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchLeagueData()
        }
        .sheet(isPresented: $showEditLeague) {
            LeagueEditView(league: league)
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
            
            if isHost {
                Button(action: {
                    showEditLeague = true
                }) {
                    Text("Edit League")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var chatTab: some View {
        LeagueChatView(leagueId: league.id, leagueName: league.name)
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
    
    private var manageTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // League Basic Info
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "LEAGUE INFO")
                    
                    Group {
                        HStack {
                            Text("League Name")
                                .fontWeight(.bold)
                            Spacer()
                            Text(league.name)
                        }
                        
                        HStack {
                            Text("Course")
                                .fontWeight(.bold)
                            Spacer()
                            Text(league.course)
                        }
                        
                        HStack {
                            Text("Schedule")
                                .fontWeight(.bold)
                            Spacer()
                            Text("\(league.schedule) on \(league.playDay.rawValue)s")
                        }
                        
                        HStack {
                            Text("Created")
                                .fontWeight(.bold)
                            Spacer()
                            Text(formatDate(league.createdAt.dateValue()))
                        }
                        
                        HStack {
                            Text("Members")
                                .fontWeight(.bold)
                            Spacer()
                            Text("\(members.count + 1)") // +1 for host
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Member Management
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "MEMBERS")
                    
                    ForEach(members) { member in
                        HStack {
                            if let profilePic = member.profilePicture, let url = URL(string: profilePic) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.circle")
                                            .resizable()
                                            .frame(width: 40, height: 40)
                                            .foregroundColor(.gray)
                                    }
                                }
                            } else {
                                Image(systemName: "person.circle")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(member.username)
                                    .font(.headline)
                                Text(member.firstName + " " + member.lastName)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.leading, 5)
                            
                            Spacer()
                            
                            Button(action: {
                                removeMember(member.id)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        // Show add member sheet
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Add Members")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()
                
                // Schedule Management
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "SCHEDULE MANAGEMENT")
                    
                    Button(action: {
                        // Regenerate schedule
                        generateSchedule()
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Generate Schedule")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        // End league
                    }) {
                        HStack {
                            Image(systemName: "flag.checkered")
                            Text("End League")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()
                
                Spacer().frame(height: 50)
            }
            .padding(.top, 20)
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
    
    private func removeMember(_ memberId: String) {
        let db = Firestore.firestore()
        
        // Remove member from the league's members array
        db.collection("leagues").document(league.id).updateData([
            "members": FieldValue.arrayRemove([memberId])
        ]) { error in
            if let error = error {
                print("Error removing member: \(error.localizedDescription)")
            } else {
                // Update the members list
                DispatchQueue.main.async {
                    self.members.removeAll { $0.id == memberId }
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

// MARK: - Supporting Views

struct ScheduleDateCard: View {
    let date: LeagueDate
    let league: EnhancedLeague
    @State private var showRSVPSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDay(date.date))
                        .font(.headline)
                    
                    Text(formatTime(date.date))
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(date.location)
                        .font(.subheadline)
                    
                    Text("\(date.confirmedCount) confirmed")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Divider()
            
            HStack {
                Spacer()
                
                Button(action: {
                    showRSVPSheet = true
                }) {
                    Text("RSVP")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .sheet(isPresented: $showRSVPSheet) {
            DateBasedRSVPView(leagueId: league.id)
        }
    }
    
    private func formatDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct RoundCard: View {
    let round: LeagueRound
    let leagueId: String
    @State private var showRoundDetail = false
    
    var body: some View {
        Button(action: {
            showRoundDetail = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Round \(round.number)")
                        .font(.headline)
                    
                    Text(formatDate(round.createdAt.dateValue()))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Score: \(round.score)")
                        .font(.headline)
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showRoundDetail) {
            RoundDetailView(leagueId: leagueId, roundId: round.id, roundNumber: round.number)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - League Edit View

struct LeagueEditView: View {
    let league: EnhancedLeague
    
    @State private var leagueName: String
    @State private var selectedCourse: String
    @State private var playDay: WeekDay
    @State private var playFrequency: String
    @State private var leaguePhoto: UIImage?
    @State private var showingPhotoPicker = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.presentationMode) var presentationMode
    
    init(league: EnhancedLeague) {
        self.league = league
        _leagueName = State(initialValue: league.name)
        _selectedCourse = State(initialValue: league.course)
        _playDay = State(initialValue: league.playDay)
        _playFrequency = State(initialValue: league.schedule)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // League Photo
                Section {
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            showingPhotoPicker = true
                        }) {
                            if let leaguePhoto = leaguePhoto {
                                Image(uiImage: leaguePhoto)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.3.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .padding(10)
                                    .foregroundColor(.white)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                // League Details
                Section(header: Text("LEAGUE DETAILS")) {
                    TextField("League Name", text: $leagueName)
                    
                    Picker("Course", selection: $selectedCourse) {
                        Text(selectedCourse).tag(selectedCourse)
                        // Add more course options
                    }
                }
                
                // Schedule
                Section(header: Text("SCHEDULE")) {
                    Picker("Play Day", selection: $playDay) {
                        ForEach(WeekDay.allCases) { day in
                            Text(day.rawValue).tag(day)
                        }
                    }
                    
                    Picker("Frequency", selection: $playFrequency) {
                        Text("Weekly").tag("Weekly")
                        Text("Every 2 Weeks").tag("Every 2 Weeks")
                        Text("Monthly").tag("Monthly")
                    }
                }
                
                // Save Button
                Section {
                    Button(action: saveChanges) {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(isLoading ? Color.gray : Color.blue)
                    .disabled(isLoading)
                }
            }
            .navigationTitle("Edit League")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingPhotoPicker) {
                PHPickerViewRepresentable(image: $leaguePhoto)
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("League Update"), message: Text(alertMessage), dismissButton: .default(Text("OK")) {
                    if alertMessage.contains("successfully") {
                        presentationMode.wrappedValue.dismiss()
                        
                        presentationMode.wrappedValue.dismiss()
                                            }
                                        })
                                    }
                                }
                            }
                            
                            private func saveChanges() {
                                guard !leagueName.isEmpty && !selectedCourse.isEmpty else {
                                    alertMessage = "Please fill in all required fields"
                                    showAlert = true
                                    return
                                }
                                
                                isLoading = true
                                
                                // First handle photo upload if needed
                                if let photo = leaguePhoto {
                                    ImageUploadService.shared.uploadImage(
                                        image: photo,
                                        path: "league_images",
                                        compressionQuality: 0.7
                                    ) { result in
                                        switch result {
                                        case .success(let photoURL):
                                            // Update league with photo URL
                                            self.updateLeague(photoURL: photoURL)
                                        case .failure(let error):
                                            // Update league without photo URL
                                            print("Failed to upload photo: \(error.localizedDescription)")
                                            self.updateLeague(photoURL: nil)
                                        }
                                    }
                                } else {
                                    // No photo to upload, just update league
                                    updateLeague(photoURL: nil)
                                }
                            }
                            
                            private func updateLeague(photoURL: String?) {
                                let db = Firestore.firestore()
                                
                                var updateData: [String: Any] = [
                                    "name": leagueName,
                                    "course": selectedCourse,
                                    "playDay": playDay.rawValue,
                                    "schedule": playFrequency
                                ]
                                
                                // Add photo URL if provided
                                if let photoURL = photoURL {
                                    updateData["photoURL"] = photoURL
                                }
                                
                                db.collection("leagues").document(league.id).updateData(updateData) { error in
                                    DispatchQueue.main.async {
                                        isLoading = false
                                        
                                        if let error = error {
                                            alertMessage = "Error updating league: \(error.localizedDescription)"
                                            showAlert = true
                                        } else {
                                            alertMessage = "League updated successfully!"
                                            showAlert = true
                                        }
                                    }
                                }
                            }
                        }

                        // MARK: - Player Detail View

                        struct PlayerDetailView: View {
                            let playerId: String
                            let playerName: String
                            let leagueId: String
                            
                            @State private var playerRounds: [PlayerRound] = []
                            @State private var isLoading = true
                            @Environment(\.presentationMode) var presentationMode
                            
                            struct PlayerRound: Identifiable {
                                let id: String
                                let date: Date
                                let score: Int
                                let course: String
                            }
                            
                            var body: some View {
                                NavigationView {
                                    VStack {
                                        if isLoading {
                                            ProgressView("Loading player data...")
                                        } else if playerRounds.isEmpty {
                                            VStack(spacing: 20) {
                                                Image(systemName: "figure.golf")
                                                    .font(.system(size: 60))
                                                    .foregroundColor(.gray)
                                                
                                                Text("No rounds recorded")
                                                    .font(.headline)
                                                    .foregroundColor(.gray)
                                            }
                                            .padding(.top, 50)
                                        } else {
                                            // Player stats at the top
                                            VStack(spacing: 8) {
                                                Text("Player Statistics")
                                                    .font(.headline)
                                                    .padding(.top)
                                                
                                                HStack(spacing: 20) {
                                                    StatBox(title: "Rounds", value: "\(playerRounds.count)")
                                                    
                                                    StatBox(title: "Avg Score", value: String(format: "%.1f", averageScore))
                                                    
                                                    StatBox(title: "Best", value: "\(bestScore)")
                                                }
                                                .padding(.horizontal)
                                            }
                                            
                                            // List of rounds
                                            List {
                                                ForEach(playerRounds.sorted(by: { $0.date > $1.date })) { round in
                                                    HStack {
                                                        VStack(alignment: .leading, spacing: 4) {
                                                            Text(formatDate(round.date))
                                                                .font(.subheadline)
                                                            
                                                            Text(round.course)
                                                                .font(.caption)
                                                                .foregroundColor(.gray)
                                                        }
                                                        
                                                        Spacer()
                                                        
                                                        Text("\(round.score)")
                                                            .font(.title3)
                                                            .fontWeight(.bold)
                                                    }
                                                    .padding(.vertical, 4)
                                                }
                                            }
                                            .listStyle(PlainListStyle())
                                        }
                                    }
                                    .navigationTitle(playerName)
                                    .navigationBarItems(trailing: Button("Done") {
                                        presentationMode.wrappedValue.dismiss()
                                    })
                                    .onAppear {
                                        fetchPlayerRounds()
                                    }
                                }
                            }
                            
                            private var averageScore: Double {
                                guard !playerRounds.isEmpty else { return 0 }
                                let total = playerRounds.reduce(0) { $0 + $1.score }
                                return Double(total) / Double(playerRounds.count)
                            }
                            
                            private var bestScore: Int {
                                guard !playerRounds.isEmpty else { return 0 }
                                return playerRounds.min(by: { $0.score < $1.score })?.score ?? 0
                            }
                            
                            private func fetchPlayerRounds() {
                                let db = Firestore.firestore()
                                db.collection("leagues").document(leagueId).collection("rounds")
                                    .whereField("userId", isEqualTo: playerId)
                                    .getDocuments { snapshot, error in
                                        DispatchQueue.main.async {
                                            isLoading = false
                                            
                                            if let error = error {
                                                print("Error fetching player rounds: \(error.localizedDescription)")
                                                return
                                            }
                                            
                                            guard let documents = snapshot?.documents else { return }
                                            
                                            var rounds: [PlayerRound] = []
                                            for document in documents {
                                                let data = document.data()
                                                
                                                if let score = data["score"] as? Int,
                                                   let dateTimestamp = data["date"] as? Timestamp,
                                                   let course = data["course"] as? String {
                                                    let round = PlayerRound(
                                                        id: document.documentID,
                                                        date: dateTimestamp.dateValue(),
                                                        score: score,
                                                        course: course
                                                    )
                                                    rounds.append(round)
                                                }
                                            }
                                            
                                            self.playerRounds = rounds
                                        }
                                    }
                            }
                            
                            private func formatDate(_ date: Date) -> String {
                                let formatter = DateFormatter()
                                formatter.dateStyle = .medium
                                return formatter.string(from: date)
                            }
                        }

                        struct StatBox: View {
                            let title: String
                            let value: String
                            
                            var body: some View {
                                VStack {
                                    Text(title)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    Text(value)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                                .frame(minWidth: 80)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }

                        // MARK: - Round Detail View

                        struct RoundDetailView: View {
                            let leagueId: String
                            let roundId: String
                            let roundNumber: Int
                            
                            @State private var playerScores: [PlayerScore] = []
                            @State private var isLoading = true
                            @Environment(\.presentationMode) var presentationMode
                            
                            struct PlayerScore: Identifiable {
                                let id: String
                                let userId: String
                                let username: String
                                let score: Int
                                let profilePicture: String?
                            }
                            
                            var body: some View {
                                NavigationView {
                                    VStack {
                                        if isLoading {
                                            ProgressView("Loading scores...")
                                        } else if playerScores.isEmpty {
                                            VStack(spacing: 20) {
                                                Image(systemName: "list.bullet")
                                                    .font(.system(size: 60))
                                                    .foregroundColor(.gray)
                                                
                                                Text("No scores submitted yet")
                                                    .font(.headline)
                                                    .foregroundColor(.gray)
                                                
                                                Button(action: {
                                                    // Submit score for this round
                                                }) {
                                                    Text("Submit Score")
                                                        .padding()
                                                        .background(Color.green)
                                                        .foregroundColor(.white)
                                                        .cornerRadius(10)
                                                }
                                            }
                                            .padding(.top, 50)
                                        } else {
                                            // Player scores list
                                            List {
                                                ForEach(Array(playerScores.enumerated()), id: \.element.id) { index, playerScore in
                                                    HStack {
                                                        Text("\(index + 1)")
                                                            .font(.headline)
                                                            .foregroundColor(.gray)
                                                            .frame(width: 30)
                                                        
                                                        if let profilePic = playerScore.profilePicture, let url = URL(string: profilePic) {
                                                            AsyncImage(url: url) { phase in
                                                                if let image = phase.image {
                                                                    image
                                                                        .resizable()
                                                                        .scaledToFill()
                                                                        .frame(width: 40, height: 40)
                                                                        .clipShape(Circle())
                                                                } else {
                                                                    Image(systemName: "person.circle")
                                                                        .resizable()
                                                                        .frame(width: 40, height: 40)
                                                                        .foregroundColor(.gray)
                                                                }
                                                            }
                                                        } else {
                                                            Image(systemName: "person.circle")
                                                                .resizable()
                                                                .frame(width: 40, height: 40)
                                                                .foregroundColor(.gray)
                                                        }
                                                        
                                                        Text(playerScore.username)
                                                            .font(.headline)
                                                            .padding(.leading, 5)
                                                        
                                                        Spacer()
                                                        
                                                        Text("\(playerScore.score)")
                                                            .font(.title2)
                                                            .fontWeight(.bold)
                                                    }
                                                    .padding(.vertical, 4)
                                                }
                                            }
                                            .listStyle(PlainListStyle())
                                        }
                                    }
                                    .navigationTitle("Round \(roundNumber)")
                                    .navigationBarItems(trailing: Button("Done") {
                                        presentationMode.wrappedValue.dismiss()
                                    })
                                    .onAppear {
                                        fetchRoundScores()
                                    }
                                }
                            }
                            
                            private func fetchRoundScores() {
                                let db = Firestore.firestore()
                                db.collection("leagues").document(leagueId).collection("rounds").document(roundId).collection("scores")
                                    .getDocuments { snapshot, error in
                                        if let error = error {
                                            print("Error fetching scores: \(error.localizedDescription)")
                                            isLoading = false
                                            return
                                        }
                                        
                                        guard let documents = snapshot?.documents else {
                                            isLoading = false
                                            return
                                        }
                                        
                                        // Get scores and fetch user details
                                        let dispatchGroup = DispatchGroup()
                                        var scores: [PlayerScore] = []
                                        
                                        for document in documents {
                                            let data = document.data()
                                            
                                            if let userId = data["userId"] as? String,
                                               let scoreValue = data["score"] as? Int {
                                                
                                                dispatchGroup.enter()
                                                
                                                // Fetch user details
                                                db.collection("users").document(userId).getDocument { userSnapshot, userError in
                                                    defer { dispatchGroup.leave() }
                                                    
                                                    if let userError = userError {
                                                        print("Error fetching user: \(userError.localizedDescription)")
                                                        return
                                                    }
                                                    
                                                    if let userData = userSnapshot?.data() {
                                                        let username = userData["username"] as? String ?? "Unknown"
                                                        let profilePicture = userData["profilePicture"] as? String
                                                        
                                                        scores.append(PlayerScore(
                                                            id: document.documentID,
                                                            userId: userId,
                                                            username: username,
                                                            score: scoreValue,
                                                            profilePicture: profilePicture
                                                        ))
                                                    }
                                                }
                                            }
                                        }
                                        
                                        dispatchGroup.notify(queue: .main) {
                                            // Sort by score (lowest first)
                                            self.playerScores = scores.sorted(by: { $0.score < $1.score })
                                            self.isLoading = false
                                        }
                                    }
                            }
                        }

                        // MARK: - Helper Struct for PHPickerViewController
//
//                        struct PHPickerRepresentable: UIViewControllerRepresentable {
//                            @Binding var image: UIImage?
//
//                            func makeUIViewController(context: Context) -> PHPickerViewController {
//                                var config = PHPickerConfiguration()
//                                config.filter = .images
//                                config.selectionLimit = 1
//
//                                let picker = PHPickerViewController(configuration: config)
//                                picker.delegate = context.coordinator
//                                return picker
//                            }
                            
//                            func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
//
//                            func makeCoordinator() -> Coordinator {
//                                Coordinator(self)
//                            }
                            
                            class Coordinator: NSObject, PHPickerViewControllerDelegate {
                                let parent: PHPickerViewRepresentable
                                
                                init(_ parent: PHPickerViewRepresentable) {
                                    self.parent = parent
                                }
                                
                                func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
                                    picker.dismiss(animated: true)
                                    
                                    guard let provider = results.first?.itemProvider else { return }
                                    
                                    if provider.canLoadObject(ofClass: UIImage.self) {
                                        provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                                            DispatchQueue.main.async {
                                                guard let self = self, let image = image as? UIImage else { return }
                                                self.parent.image = image
                                            }
                                        }
                                    }
                                }
                            }


                        // MARK: - Preview

                        struct EnhancedLeagueDetailView_Previews: PreviewProvider {
                            static var previews: some View {
                                EnhancedLeagueDetailView(
                                    league: EnhancedLeague(
                                        id: "1",
                                        name: "Tuesday Night League",
                                        hostUserId: "user123",
                                        members: ["user456", "user789"],
                                        course: "Armitage Golf Club",
                                        schedule: "Weekly",
                                        playDay: .tuesday,
                                        createdAt: Timestamp(date: Date())
                                    ),
                                    isHost: true
                                )
                            }
                        }

                        // MARK: - SectionHeader Component

//                        struct SectionHeader: View {
//                            let title: String
//
//                            var body: some View {
//                                Text(title)
//                                    .font(.subheadline)
//                                    .fontWeight(.semibold)
//                                    .foregroundColor(.gray)
//                                    .padding(.top, 10)
//                            }
//                        }
