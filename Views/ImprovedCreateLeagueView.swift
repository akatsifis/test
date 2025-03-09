import SwiftUI
import Firebase
import PhotosUI

struct ImprovedCreateLeagueView: View {
    // League details
    @State private var leagueName = ""
    @State private var selectedCourse: GolfCourse?
    @State private var showingCourseSelector = false
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
    
    // Environment objects
    @EnvironmentObject private var locationManager: AppLocationManager
    
    // Load nearby courses when view appears
    @State private var nearbyCoursesLoaded = false
    @State private var nearbyCourses: [GolfCourse] = []
    
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
                
                // Course Selection - Now with nearby courses suggestion
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("HOME COURSE")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        if locationManager.currentLocation != nil && !nearbyCourses.isEmpty {
                            Spacer()
                            Text("Nearby Courses Found")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    // Selected course or button to select
                    if let course = selectedCourse {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(course.Name)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("\(course.City), \(course.State)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let distance = locationManager.distance(to: course.coordinate) {
                                    Text(String(format: "%.1f miles away", distance / 1609.344))
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showingCourseSelector = true
                            }) {
                                Text("Change")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        Button(action: {
                            showingCourseSelector = true
                        }) {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(.green)
                                
                                Text("Select a course")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Show nearby courses if available
                    if locationManager.currentLocation != nil && !nearbyCourses.isEmpty && selectedCourse == nil {
                        Text("NEARBY COURSES")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 5)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(nearbyCourses.prefix(5), id: \.id) { course in
                                    Button(action: {
                                        selectedCourse = course
                                    }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(course.Name)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .multilineTextAlignment(.leading)
                                                .lineLimit(2)
                                            
                                            if let distance = locationManager.distance(to: course.coordinate) {
                                                Text(String(format: "%.1f mi", distance / 1609.344))
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                            }
                                        }
                                        .frame(width: 120, alignment: .leading)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
                
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
            .sheet(isPresented: $showingCourseSelector) {
                NavigationView {
                    CourseSearchView(selectedCourse: $selectedCourse)
                        .navigationTitle("Select a Course")
                        .navigationBarItems(trailing: Button("Done") {
                            showingCourseSelector = false
                        })
                        .environmentObject(locationManager)
                }
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
        .onAppear {
            // If we have location, load nearby courses when view appears
            if !nearbyCoursesLoaded {
                loadNearbyCourses()
            }
        }
    }
    
    private func loadNearbyCourses() {
        // If we have location, find nearby courses
        if let _ = locationManager.currentLocation {
            nearbyCourses = locationManager.findNearbyCourses()
            nearbyCoursesLoaded = true
        } else {
            // Request location if not available and try again after getting it
            locationManager.requestLocationIfNeeded()
            
            // Check for location after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let _ = locationManager.currentLocation {
                    nearbyCourses = locationManager.findNearbyCourses()
                    nearbyCoursesLoaded = true
                }
            }
        }
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
        !leagueName.isEmpty && selectedCourse != nil
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
        
        // Get course information
        guard let course = selectedCourse else {
            isCreating = false
            alertMessage = "Please select a golf course"
            showAlert = true
            return
        }
        
        // Prepare league data
        var leagueData: [String: Any] = [
            "name": leagueName,
            "hostUserId": currentUserId,
            "members": memberIds,
            "course": course.Name,
            "courseId": course.id,
            "courseLocation": "\(course.City), \(course.State)",
            "courseLat": course.Latitude,
            "courseLng": course.Longitude,
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
        selectedCourse = nil
        leagueDescription = ""
        leaguePhoto = nil
        playFrequency = .weekly
        selectedDay = .monday
        teeTime = Date()
        selectedMembers = []
        addMembersLater = true
    }
}
