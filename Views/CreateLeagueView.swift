import SwiftUI

struct CreateLeagueView: View {
    @State private var searchQuery = ""
    @State private var users: [Models.User] = []
    @State private var selectedUsers: [Models.User] = []
    @State private var leagueName = ""
    @State private var selectedCourse: GolfCourse?
    @State private var showingCourseSelector = false
    
    var body: some View {
        VStack {
            // League Name Field
            TextField("League Name", text: $leagueName)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .padding(.bottom)
            
            // Course Selection Button
            Button(action: {
                showingCourseSelector = true
            }) {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.green)
                    
                    if let course = selectedCourse {
                        VStack(alignment: .leading) {
                            Text(course.Name)
                                .fontWeight(.semibold)
                            Text("\(course.City), \(course.State)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Select Home Course")
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.bottom)
            .sheet(isPresented: $showingCourseSelector) {
                NavigationView {
                    CourseSearchView(selectedCourse: $selectedCourse)
                        .navigationTitle("Select Course")
                        .navigationBarItems(trailing: Button("Done") {
                            showingCourseSelector = false
                        })
                }
            }
            
            Text("Add Players")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top)
            
            // Search Bar
            TextField("Search by username or phone number", text: $searchQuery)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .onChange(of: searchQuery) { newValue in
                    // Call search function when the query changes
                    if newValue.isEmpty {
                        users = [] // Clear users if search query is empty
                    } else {
                        searchUsers(query: newValue) // Fetch users based on the query
                    }
                }
            
            // Selected Users List
            if !selectedUsers.isEmpty {
                Text("Selected Players")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(selectedUsers, id: \.id) { user in
                            VStack {
                                if let profilePicture = user.profilePicture, let url = URL(string: profilePicture) {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } else {
                                            Image(systemName: "person.circle.fill")
                                        }
                                    }
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                }
                                
                                Text(user.username)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .frame(width: 60)
                            .onTapGesture {
                                // Remove user when tapped
                                selectedUsers.removeAll { $0.id == user.id }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            
            // Display search results
            List(users, id: \.id) { user in
                Button(action: {
                    // Add user to selected users if not already selected
                    if !selectedUsers.contains(where: { $0.id == user.id }) {
                        selectedUsers.append(user)
                    }
                }) {
                    HStack {
                        // Display Profile Picture
                        if let profilePicture = user.profilePicture {
                            // Check if it's a valid URL
                            if let url = URL(string: profilePicture) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 50, height: 50)
                                            .clipShape(Circle())
                                    } else if phase.error != nil {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 50, height: 50)
                                    } else {
                                        ProgressView()
                                            .frame(width: 50, height: 50)
                                    }
                                }
                            } else {
                                // Fallback if profilePicture is not a valid URL
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                            }
                        } else {
                            // If profilePicture is nil, show default image
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                        }
                        
                        // Display Username and Phone Number
                        VStack(alignment: .leading) {
                            Text(user.username)
                                .font(.headline)
                            Text(user.phoneNumber)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        // Show check mark if user is selected
                        if selectedUsers.contains(where: { $0.id == user.id }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Create League Button
            Button(action: {
                createLeague()
            }) {
                Text("Create League")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canCreateLeague ? Color.green : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(!canCreateLeague)
            .padding()
        }
        .padding()
        .navigationTitle("Create League")
    }
    
    // Check if we can create the league
    private var canCreateLeague: Bool {
        !leagueName.isEmpty && selectedCourse != nil && !selectedUsers.isEmpty
    }
    
    // Search function to fetch users based on query
    private func searchUsers(query: String) {
        UserService.shared.searchUsers(query: query) { result in
            switch result {
            case .success(let fetchedUsers):
                self.users = fetchedUsers
            case .failure(let error):
                print("Error searching users: \(error.localizedDescription)")
                self.users = [] // Clear results on error
            }
        }
    }
    
    // Create the league with selected users and course
    private func createLeague() {
        guard let course = selectedCourse, !leagueName.isEmpty, !selectedUsers.isEmpty else {
            return
        }
        
        // Create league data
        let leagueData: [String: Any] = [
            "name": leagueName,
            "courseName": course.Name,
            "courseId": course.id,
            "courseLocation": "\(course.City), \(course.State)",
            "createdAt": Date(),
            "members": selectedUsers.map { $0.id }
        ]
        
        // Call your service to create the league
        // Example:
        // LeagueService.shared.createLeague(leagueData: leagueData) { result in
        //     // Handle result
        // }
    }
}
