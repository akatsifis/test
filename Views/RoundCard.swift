//
//  RoundCard.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/8/25.
//


import SwiftUI
import FirebaseFirestore

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