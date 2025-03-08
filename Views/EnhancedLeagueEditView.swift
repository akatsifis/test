import SwiftUI
import Firebase
import FirebaseFirestore
import PhotosUI

struct EnhancedLeagueEditView: View {
    let league: EnhancedLeague
    
    @State private var leagueName: String
    @State private var selectedCourse: String
    @State private var playDay: WeekDay
    @State private var playFrequency: String
    @State private var teeTime: Date
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
        
        // Initialize tee time from league or use default (12:00 PM)
        if let nextScheduledDate = league.nextScheduledDate {
            _teeTime = State(initialValue: nextScheduledDate.dateValue())
        } else {
            let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
            _teeTime = State(initialValue: noon)
        }
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
                    
                    DatePicker("Tee Time", selection: $teeTime, displayedComponents: .hourAndMinute)
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

                // End League Button
                Section {
                    Button(action: endLeague) {
                        Text("End League")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.red)
                }
                
                // Member Management
                Section(header: Text("MEMBER MANAGEMENT")) {
                    NavigationLink(destination: MemberManagementView(
                        league: league,
                        members: [],
                        onRemoveMember: { memberId in
                            // Implement member removal logic
                        }
                    )) {
                        Text("Manage Members")
                    }
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
                    }
                })
            }
        }
    }
    
    private func saveChanges() {
        guard !leagueName.isEmpty && !selectedCourse.isEmpty else { return }
        
        isLoading = true
        
        // First handle photo upload if needed
        if let photo = leaguePhoto {
            uploadLeaguePhoto(photo) { result in
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
    
    private func uploadLeaguePhoto(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        ImageUploadService.shared.uploadImage(
            image: image,
            path: "league_images",
            compressionQuality: 0.7,
            completion: completion
        )
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
        
        // Update league document with new info
        db.collection("leagues").document(league.id).updateData(updateData) { [self] error in
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.alertMessage = "Error updating league: \(error.localizedDescription)"
                    self.showAlert = true
                }
                return
            }
            
            // Update the next scheduled date based on the new tee time
            self.updateNextScheduledDate {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.alertMessage = "League updated successfully!"
                    self.showAlert = true
                }
            }
        }
    }
    
    private func updateNextScheduledDate(completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        
        // Calculate the next occurrence of the selected day
        var nextDate = calculateNextPlayDate()
        
        // Update the nextScheduledDate field
        db.collection("leagues").document(league.id).updateData([
            "nextScheduledDate": Timestamp(date: nextDate)
        ]) { error in
            if let error = error {
                print("Error updating next scheduled date: \(error.localizedDescription)")
            }
            
            // Also update any future dates collection if it exists
            self.updateFutureDates(baseDate: nextDate)
            
            completion()
        }
    }
    
    private func calculateNextPlayDate() -> Date {
        // Get components from current date
        let currentDate = Date()
        let calendar = Calendar.current
        
        // Find the next occurrence of the selected day
        let currentWeekday = calendar.component(.weekday, from: currentDate)
        let targetWeekday = playDay.toWeekdayInt()
        
        // Calculate days to add to reach the target weekday
        var daysToAdd = targetWeekday - currentWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7 // Move to next week if target is today or earlier in week
        }
        
        let nextPlayDay = calendar.date(byAdding: .day, value: daysToAdd, to: currentDate)!
        
        // Combine the next play day with the selected tee time
        let timeComponents = calendar.dateComponents([.hour, .minute], from: teeTime)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: nextPlayDay)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        
        return calendar.date(from: dateComponents)!
    }
    
    private func updateFutureDates(baseDate: Date) {
        let db = Firestore.firestore()
        let calendar = Calendar.current
        
        // Extract time components from the tee time picker
        let timeComponents = calendar.dateComponents([.hour, .minute], from: teeTime)
        
        // Get all future dates
        db.collection("leagues").document(league.id).collection("dates")
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: Date()))
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching future dates: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    // No future dates to update
                    return
                }
                
                let batch = db.batch()
                
                // Update each date document with the new tee time
                for document in documents {
                    // Get the current date from the document
                    if let timestamp = document.data()["date"] as? Timestamp {
                        let date = timestamp.dateValue()
                        
                        // Extract just the date components (year, month, day)
                        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
                        
                        // Apply the tee time hours and minutes
                        dateComponents.hour = timeComponents.hour
                        dateComponents.minute = timeComponents.minute
                        dateComponents.second = 0
                        
                        // Create new date with correct time
                        if let newDate = calendar.date(from: dateComponents) {
                            // Update the document with the new date and time
                            batch.updateData([
                                "date": Timestamp(date: newDate),
                                "teeTime": Timestamp(date: newDate)
                            ], forDocument: document.reference)
                            
                            print("Updating date to: \(newDate)")
                        }
                    }
                }
                
                // Commit all the updates
                batch.commit { error in
                    if let error = error {
                        print("Error updating future dates: \(error.localizedDescription)")
                    } else {
                        print("Successfully updated \(documents.count) future league dates")
                    }
                }
            }
    }
    
    private func getNextDateByFrequency(currentDate: Date) -> Date {
        let calendar = Calendar.current
        
        // Calculate next date based on frequency
        switch playFrequency {
        case "Weekly":
            return calendar.date(byAdding: .day, value: 7, to: currentDate)!
        case "Every 2 Weeks", "Bi-weekly":
            return calendar.date(byAdding: .day, value: 14, to: currentDate)!
        case "Monthly":
            return calendar.date(byAdding: .month, value: 1, to: currentDate)!
        default:
            return calendar.date(byAdding: .day, value: 7, to: currentDate)!
        }
    }
    
    private func endLeague() {
        let db = Firestore.firestore()
        
        isLoading = true
        
        // Update league status to inactive
        db.collection("leagues").document(league.id).updateData([
            "isActive": false
        ]) { error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    alertMessage = "Error ending league: \(error.localizedDescription)"
                    showAlert = true
                } else {
                    alertMessage = "League has been ended successfully"
                    showAlert = true
                    // Close the view after successful update
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

struct MemberManagementView: View {
    let league: EnhancedLeague
    let members: [Models.User]
    let onRemoveMember: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MEMBERS")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
                .padding(.top, 10)
            
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
                        onRemoveMember(member.id)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            if members.isEmpty {
                Text("No members in this league")
                    .foregroundColor(.gray)
                    .italic()
                    .padding()
            }
            
            NavigationLink(destination: AddMembersView(leagueId: league.id)) {
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
    }
}

struct AddMembersView: View {
    let leagueId: String
    @State private var searchQuery = ""
    @State private var users: [Models.User] = []
    @State private var isSearching = false
    @State private var selectedUsers: [Models.User] = []
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search by username or phone", text: $searchQuery)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        users = []
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
            .onChange(of: searchQuery) { newValue in
                if newValue.count >= 3 {
                    searchUsers(query: newValue)
                } else if newValue.isEmpty {
                    users = []
                }
            }
            
            // Selected users
            if !selectedUsers.isEmpty {
                VStack(alignment: .leading) {
                    Text("Selected Users")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(selectedUsers) { user in
                                VStack {
                                    if let profilePicture = user.profilePicture, let url = URL(string: profilePicture) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 50, height: 50)
                                                    .clipShape(Circle())
                                            } else {
                                                Image(systemName: "person.circle.fill")
                                                    .resizable()
                                                    .frame(width: 50, height: 50)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .frame(width: 50, height: 50)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Text(user.username)
                                        .font(.caption)
                                        .lineLimit(1)
                                    
                                    Button(action: {
                                        selectedUsers.removeAll { $0.id == user.id }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                                .frame(width: 70)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            if isSearching {
                ProgressView("Searching...")
                    .padding()
            } else if !users.isEmpty {
                List {
                    ForEach(users) { user in
                        HStack {
                            if let profilePicture = user.profilePicture, let url = URL(string: profilePicture) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .frame(width: 40, height: 40)
                                            .foregroundColor(.gray)
                                    }
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(user.username)
                                    .font(.headline)
                                
                                if !user.phoneNumber.isEmpty {
                                    Text(user.phoneNumber)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.leading, 5)
                            
                            Spacer()
                            
                            Button(action: {
                                toggleUserSelection(user)
                            }) {
                                Image(systemName: selectedUsers.contains(where: { $0.id == user.id }) ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundColor(selectedUsers.contains(where: { $0.id == user.id }) ? .green : .blue)
                            }
                        }
                    }
                }
            }
            
            // Add Members Button
            Button(action: addMembersToLeague) {
                Text("Add Selected Members")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(selectedUsers.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(10)
                    .padding()
            }
            .disabled(selectedUsers.isEmpty)
        }
        .navigationTitle("Add Members")
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Add Members"), message: Text(alertMessage), dismissButton: .default(Text("OK")) {
                if alertMessage.contains("successfully") {
                    presentationMode.wrappedValue.dismiss()
                }
            })
        }
    }
    
    private func searchUsers(query: String) {
        isSearching = true
        
        UserService.shared.searchUsers(query: query) { result in
            DispatchQueue.main.async {
                isSearching = false
                
                switch result {
                case .success(let fetchedUsers):
                    // Filter out already selected users and current user
                    guard let currentUserId = Auth.auth().currentUser?.uid else {
                        self.users = fetchedUsers
                        return
                    }
                    
                    // Fetch current league to check existing members
                    let db = Firestore.firestore()
                    db.collection("leagues").document(leagueId).getDocument { snapshot, error in
                        if let error = error {
                            print("Error fetching league: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let data = snapshot?.data() else { return }
                        
                        // Get existing member IDs
                        let hostUserId = data["hostUserId"] as? String ?? ""
                        let existingMembers = data["members"] as? [String] ?? []
                        
                        // Filter users who are not already members or the host
                        self.users = fetchedUsers.filter { user in
                            return user.id != currentUserId &&
                                   user.id != hostUserId &&
                                   !existingMembers.contains(user.id) &&
                                   !self.selectedUsers.contains(where: { $0.id == user.id })
                        }
                    }
                    
                case .failure(let error):
                    print("Error searching users: \(error.localizedDescription)")
                    self.users = []
                }
            }
        }
    }
    
    private func toggleUserSelection(_ user: Models.User) {
        if let index = selectedUsers.firstIndex(where: { $0.id == user.id }) {
            selectedUsers.remove(at: index)
        } else {
            selectedUsers.append(user)
        }
    }
    
    private func addMembersToLeague() {
        guard !selectedUsers.isEmpty else { return }
        
        let memberIds = selectedUsers.map { $0.id }
        let db = Firestore.firestore()
        
        db.collection("leagues").document(leagueId).updateData([
            "members": FieldValue.arrayUnion(memberIds)
        ]) { error in
            if let error = error {
                alertMessage = "Failed to add members: \(error.localizedDescription)"
            } else {
                alertMessage = "Members added successfully"
            }
            showAlert = true
        }
    }
}

// We're using the PHPickerViewRepresentable from elsewhere in the project
