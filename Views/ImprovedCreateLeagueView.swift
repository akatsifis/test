import SwiftUI
import Firebase
import PhotosUI

struct ImprovedCreateLeagueView: View {
    // League details
    @State private var leagueName = ""
    @State private var selectedCourse = ""
    @State private var leagueDescription = ""
    @State private var leaguePhoto: UIImage?
    @State private var showingPhotoPicker = false
    
    // Schedule options
    @State private var playFrequency = PlayFrequency.weekly
    @State private var selectedDay = WeekDay.monday
    @State private var teeTime = Date()
    
    // Member management
    @State private var searchQuery = ""
    @State private var users: [Models.User] = []
    @State private var isSearching = false
    @State private var selectedMembers: [Models.User] = []
    @State private var addMembersLater = true
    
    // UI states
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingSuccessAlert = false
    @State private var isCreating = false
    
    // Course options
    let courses = ["Armitage Golf Club", "Rich Valley Golf", "Dauphin Highlands",
                  "Cumberland Golf Club", "Mayapple Golf Club"]
    
    enum PlayFrequency: String, CaseIterable, Identifiable {
        case weekly = "Weekly"
        case biweekly = "Every 2 Weeks"
        case monthly = "Monthly"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // League photo
                VStack(alignment: .center, spacing: 10) {
                    if let leaguePhoto = leaguePhoto {
                        Image(uiImage: leaguePhoto)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                    } else {
                        Image(systemName: "person.3.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 90, height: 90)
                            .padding(15)
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    
                    Button("Add League Photo") {
                        showingPhotoPicker = true
                    }
                    .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
                
                // League Details Section
                SectionHeader(title: "LEAGUE DETAILS")
                
                TextField("League Name", text: $leagueName)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                Picker("Golf Course", selection: $selectedCourse) {
                    Text("Select a course").tag("")
                    ForEach(courses, id: \.self) { course in
                        Text(course).tag(course)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                
                TextField("League Description (optional)", text: $leagueDescription)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .frame(height: 100)
                
                // Schedule Section
                SectionHeader(title: "SCHEDULE")
                
                Picker("Frequency", selection: $playFrequency) {
                    ForEach(PlayFrequency.allCases) { frequency in
                        Text(frequency.rawValue).tag(frequency)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.vertical, 5)
                
                Picker("Play Day", selection: $selectedDay) {
                    ForEach(WeekDay.allCases) { day in
                        Text(day.rawValue).tag(day)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                
                DatePicker("Tee Time", selection: $teeTime, displayedComponents: .hourAndMinute)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                // Members Section
                SectionHeader(title: "MEMBERS")
                
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Add members later", isOn: $addMembersLater)
                        .padding(.vertical, 5)
                }
                
                if !addMembersLater {
                    memberSearchSection
                }
                
                // Create Button
                Button(action: createLeague) {
                    if isCreating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create League")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(isCreating || !isFormValid ? Color.gray : Color.blue)
                .cornerRadius(10)
                .disabled(isCreating || !isFormValid)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
            .padding()
            .sheet(isPresented: $showingPhotoPicker) {
                PHPickerViewRepresentable(image: $leaguePhoto)
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("League Creation"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .alert("League Created Successfully", isPresented: $showingSuccessAlert) {
                Button("OK", role: .cancel) {
                    // Navigate back or to the new league
                }
            }
        }
        .navigationTitle("Create League")
    }
    
    private var memberSearchSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                TextField("Search by username or phone number", text: $searchQuery)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                if isSearching {
                    ProgressView()
                        .padding(.trailing)
                }
            }
            .onChange(of: searchQuery) { newValue in
                if newValue.isEmpty {
                    users = [] // Clear users if search query is empty
                } else if newValue.count >= 3 {
                    isSearching = true
                    searchUsers(query: newValue)
                }
            }
            
            // Selected Members
            if !selectedMembers.isEmpty {
                VStack(alignment: .leading) {
                    Text("Selected Members")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(selectedMembers) { member in
                                VStack {
                                    if let profilePicture = member.profilePicture,
                                       let url = URL(string: profilePicture) {
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
                                    
                                    Text(member.username)
                                        .font(.caption)
                                        .lineLimit(1)
                                    
                                    Button(action: {
                                        selectedMembers.removeAll { $0.id == member.id }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                                .frame(width: 70)
                            }
                        }
                    }
                }
                .padding(.vertical, 10)
            }
            
            // Search Results
            if !users.isEmpty {
                Text("Search Results")
                    .font(.headline)
                    .padding(.top, 5)
                
                ForEach(users) { user in
                    HStack {
                        // Profile Picture
                        if let profilePicture = user.profilePicture,
                           let url = URL(string: profilePicture) {
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
                        
                        // User Details
                        VStack(alignment: .leading) {
                            Text(user.username)
                                .font(.headline)
                            Text(user.phoneNumber)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.leading, 5)
                        
                        Spacer()
                        
                        // Add/Remove Button
                        Button(action: {
                            if selectedMembers.contains(where: { $0.id == user.id }) {
                                selectedMembers.removeAll { $0.id == user.id }
                            } else {
                                selectedMembers.append(user)
                            }
                        }) {
                            Image(systemName: selectedMembers.contains(where: { $0.id == user.id }) ?
                                  "checkmark.circle.fill" : "plus.circle")
                                .resizable()
                                .frame(width: 25, height: 25)
                                .foregroundColor(selectedMembers.contains(where: { $0.id == user.id }) ?
                                                 .green : .blue)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !leagueName.isEmpty && !selectedCourse.isEmpty
    }
    
    // Search function to fetch users based on query
    private func searchUsers(query: String) {
        UserService.shared.searchUsers(query: query) { result in
            DispatchQueue.main.async {
                self.isSearching = false
                
                switch result {
                case .success(let fetchedUsers):
                    // Filter out already selected users and current user
                    guard let currentUserId = Auth.auth().currentUser?.uid else {
                        self.users = fetchedUsers
                        return
                    }
                    
                    self.users = fetchedUsers.filter { user in
                        !self.selectedMembers.contains(where: { $0.id == user.id }) &&
                        user.id != currentUserId
                    }
                    
                case .failure(let error):
                    print("Error searching users: \(error.localizedDescription)")
                    self.users = [] // Clear results on error
                }
            }
        }
    }
    
    private func createLeague() {
        guard isFormValid else { return }
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            alertMessage = "You must be logged in to create a league"
            showAlert = true
            return
        }
        
        isCreating = true
        
        // Prepare member IDs
        let memberIds = addMembersLater ? [] : selectedMembers.map { $0.id }
        
        // Step 1: Upload league photo if available
        if let leaguePhoto = leaguePhoto {
            uploadLeaguePhoto(leaguePhoto) { result in
                switch result {
                case .success(let photoURL):
                    // Step 2: Create the league with photo URL
                    self.saveLeagueToFirestore(currentUserId: currentUserId, memberIds: memberIds, photoURL: photoURL)
                case .failure(let error):
                    // Failed to upload photo, create league without photo
                    print("Failed to upload league photo: \(error.localizedDescription)")
                    self.saveLeagueToFirestore(currentUserId: currentUserId, memberIds: memberIds, photoURL: nil)
                }
            }
        } else {
            // No photo to upload, create league directly
            saveLeagueToFirestore(currentUserId: currentUserId, memberIds: memberIds, photoURL: nil)
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
    
    private func saveLeagueToFirestore(currentUserId: String, memberIds: [String], photoURL: String?) {
        let db = Firestore.firestore()
        
        // Calculate next play date based on schedule
        let nextPlayDate = calculateNextPlayDate()
        
        // Prepare league data
        var leagueData: [String: Any] = [
            "name": leagueName,
            "hostUserId": currentUserId,
            "members": memberIds,
            "course": selectedCourse,
            "schedule": playFrequency.rawValue,
            "playDay": selectedDay.rawValue,
            "createdAt": Timestamp(date: Date()),
            "isActive": true,
            "totalRounds": 0,
            "nextScheduledDate": Timestamp(date: nextPlayDate)
        ]
        
        // Add optional fields
        if !leagueDescription.isEmpty {
            leagueData["description"] = leagueDescription
        }
        
        if let photoURL = photoURL {
            leagueData["photoURL"] = photoURL
        }
        
        // Save to Firestore
        db.collection("leagues").addDocument(data: leagueData) { error in
            DispatchQueue.main.async {
                self.isCreating = false
                
                if let error = error {
                    self.alertMessage = "Failed to create league: \(error.localizedDescription)"
                    self.showAlert = true
                } else {
                    self.showingSuccessAlert = true
                    // Reset form
                    self.resetForm()
                }
            }
        }
    }
    
    private func calculateNextPlayDate() -> Date {
        // Get components from current date
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        
        // Find next occurrence of the selected day
        let currentWeekday = Calendar.current.component(.weekday, from: Date())
        let targetWeekday = selectedDay.toWeekdayInt()
        
        // Calculate days to add to reach the target weekday
        var daysToAdd = targetWeekday - currentWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7 // Move to next week if target is today or earlier in week
        }
        
        let nextPlayDay = Calendar.current.date(byAdding: .day, value: daysToAdd, to: Date())!
        
        // Combine the next play day with the selected tee time
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: teeTime)
        components.year = Calendar.current.component(.year, from: nextPlayDay)
        components.month = Calendar.current.component(.month, from: nextPlayDay)
        components.day = Calendar.current.component(.day, from: nextPlayDay)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        
        return Calendar.current.date(from: components)!
    }
    
    private func resetForm() {
        leagueName = ""
        selectedCourse = ""
        leagueDescription = ""
        leaguePhoto = nil
        playFrequency = .weekly
        selectedDay = .monday
        teeTime = Date()
        selectedMembers = []
        addMembersLater = true
    }
}

//// Helper structures
//struct SectionHeader: View {
//    let title: String
//    
//    var body: some View {
//        Text(title)
//            .font(.subheadline)
//            .fontWeight(.semibold)
//            .foregroundColor(.gray)
//            .padding(.top, 10)
//    }
//}

// Photo picker using PHPickerViewController for iOS 14+
struct PHPickerViewRepresentable: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
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
}
