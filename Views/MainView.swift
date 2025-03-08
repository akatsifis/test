import SwiftUI

struct MainView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var notificationManager: AldoNotificationManager
    @State private var showingNotifications = false
    
    // Set a fixed size for buttons
    let buttonWidth: CGFloat = 300
    let buttonHeight: CGFloat = 60

    var body: some View {
        NavigationView {
            ZStack {
                // Background Image
                Image("Armitage")
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    Spacer()

                    // "Play Now" button - Using EnhancedPlayNowView
                    NavigationLink(destination: EnhancedPlayNowView()) {
                        Text("Play Now")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(width: buttonWidth, height: buttonHeight)
                            .background(Color.black.opacity(0.9))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }

                    // "View Activity" button
                    NavigationLink(destination: ActivityView()) {
                        Text("View Activity")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(width: buttonWidth, height: buttonHeight)
                            .background(Color.black.opacity(0.9))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }

                    // "View Friends" button
                    NavigationLink(destination: FriendsListView()) {
                        Text("View Friends")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(width: buttonWidth, height: buttonHeight)
                            .background(Color.black.opacity(0.9))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }

                    // "View Profile" button
                    NavigationLink(destination: ProfileView()) {
                        Text("View Profile")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(width: buttonWidth, height: buttonHeight)
                            .background(Color.black.opacity(0.9))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }

                    // "League Play" button
                    NavigationLink(destination: LeaguePlayView()) {
                        Text("League Play")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(width: buttonWidth, height: buttonHeight)
                            .background(Color.black.opacity(0.9))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }

                    // "Log Out" button
                    Button(action: {
                        authManager.logout()
                    }) {
                        Text("Log Out")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(width: buttonWidth, height: buttonHeight)
                            .background(Color.red.opacity(0.7))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }

                    Spacer() // To ensure buttons are positioned towards the top
                }
                .padding(.horizontal, 20)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNotifications = true
                    }) {
                        ZStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 22))
                            
                            AldoNotificationBadge(count: notificationManager.unreadCount)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNotifications) {
                AldoNotificationView()
            }
        }
    }
}

struct LeaguePlayView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Choose an option to proceed")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 50)
            
            // "Create a League" button - using ImprovedCreateLeagueView
            NavigationLink("Create a League", destination: ImprovedCreateLeagueView())
                .font(.title2)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.black)
                .cornerRadius(10)
                .shadow(radius: 5)
            
            // "My Leagues" button
            NavigationLink("My Leagues", destination: LeagueDashboardView())
                .font(.title2)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(radius: 5)

            // "Search Leagues" button
            NavigationLink("Search for a League", destination: SearchLeaguesView())
                .font(.title2)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(radius: 5)

            Spacer()
        }
        .padding()
    }
}
