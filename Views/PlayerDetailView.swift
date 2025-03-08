//
//  PlayerDetailView.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/8/25.
//


import SwiftUI
import Firebase
import FirebaseFirestore

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