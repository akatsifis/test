import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct LeagueDashboardView: View {
    @State private var userLeagues: [EnhancedLeague] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var showCreateLeague = false
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading your leagues...")
            } else if let error = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                        .padding()
                    
                    Text(error)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button(action: fetchLeagues) {
                        Text("Try Again")
                            .fontWeight(.semibold)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            } else if userLeagues.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "person.3")
                        .font(.system(size: 70))
                        .foregroundColor(.gray)
                        .padding()
                    
                    Text("You're not part of any leagues yet")
                        .font(.title3)
                        .foregroundColor(.gray)
                    
                    Text("Create a league or ask a friend to add you to theirs")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    Button(action: {
                        showCreateLeague = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create a League")
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.top, 20)
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(userLeagues) { league in
                            NavigationLink(destination: EnhancedLeagueDetailView(
                                league: league,
                                isHost: league.hostUserId == Auth.auth().currentUser?.uid
                            )) {
                                LeagueCardView(league: league)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("My Leagues")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showCreateLeague = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear(perform: fetchLeagues)
        .sheet(isPresented: $showCreateLeague) {
            ImprovedCreateLeagueView()
        }
        .refreshable {
            await refreshData()
        }
    }
    
    // Fetch leagues
    private func fetchLeagues() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            errorMessage = "Please sign in to view your leagues"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        EnhancedLeagueService.shared.fetchUserLeagues(forUser: userId) { result in
            isLoading = false
            
            switch result {
            case .success(let leagues):
                self.userLeagues = leagues
            case .failure(let error):
                self.errorMessage = "Failed to load leagues: \(error.localizedDescription)"
            }
        }
    }
    
    // Refresh data for pull-to-refresh
    private func refreshData() async {
        await withCheckedContinuation { continuation in
            fetchLeagues()
            // Add slight delay for UI feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                continuation.resume()
            }
        }
    }
}

struct LeagueCardView: View {
    let league: EnhancedLeague
    @State private var memberCount: Int = 0
    @State private var isHost: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with league name and status
            HStack {
                Text(league.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isHost {
                    Text("Host")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            Divider()
            
            // League details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Course")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(league.course)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schedule")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(league.schedule)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Members")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("\(memberCount)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
            
            // Next meeting info if available
            if let nextDate = league.nextScheduledDate {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Play")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(formatDate(nextDate.dateValue()))
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onAppear {
            memberCount = league.members.count + 1 // +1 for host
            isHost = league.hostUserId == Auth.auth().currentUser?.uid
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
