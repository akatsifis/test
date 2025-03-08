import SwiftUI

struct CreateLeagueView: View {
    @State private var searchQuery = ""
    @State private var users: [Models.User] = []
    
    var body: some View {
        VStack {
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
            
            // Display search results
            List(users, id: \.id) { user in
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
                }
                .padding()
            }
        }
        .padding()
        .navigationTitle("Create League")
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
}

struct CreateLeagueView_Previews: PreviewProvider {
    static var previews: some View {
        CreateLeagueView()
    }
}
