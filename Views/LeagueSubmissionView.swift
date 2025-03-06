//
//  LeagueSubmissionView.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/5/25.
//


import SwiftUI
import Firebase
import FirebaseFirestore

struct LeagueSubmissionView: View {
    let score: Int
    let course: String
    let holeCount: Int
    let steps: Int
    let distance: Double
    let calories: Double
    let onSubmit: (String) -> Void
    
    @State private var leagues: [LeagueInfo] = []
    @State private var selectedLeagueId: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 20) {
                    Text("Submit to League")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    // Score summary
                    VStack(spacing: 12) {
                        HStack {
                            Text("Course:")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(course)
                        }
                        
                        HStack {
                            Text("Score:")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(score)")
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            Text("Holes:")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(holeCount)")
                        }
                        
                        HStack {
                            Text("Steps:")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(steps)")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView("Loading leagues...")
                            .padding()
                    } else if leagues.isEmpty {
                        VStack(spacing: 15) {
                            Text("You don't have any leagues")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            NavigationLink(destination: CreateLeagueView()) {
                                Text("Create a League")
                                    .font(.headline)
                                    .padding()
                                    .frame(width: geometry.size.width * 0.8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                    } else {
                        // League picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Choose a League")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Picker("Select League", selection: $selectedLeagueId) {
                                Text("Select a league").tag("")
                                ForEach(leagues) { league in
                                    Text(league.name).tag(league.id)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 2)
                            .padding(.horizontal)
                        }
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding()
                        }
                        
                        Spacer()
                        
                        // Submit button
                        Button(action: {
                            if !selectedLeagueId.isEmpty {
                                onSubmit(selectedLeagueId)
                            }
                        }) {
                            Text("Submit Score")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: geometry.size.width * 0.8)
                                .padding(.vertical, 16)
                                .background(selectedLeagueId.isEmpty ? Color.gray : Color.green)
                                .cornerRadius(15)
                        }
                        .disabled(selectedLeagueId.isEmpty)
                        .padding(.bottom, 30)
                    }
                }
                .frame(width: geometry.size.width)
                .onAppear {
                    fetchUserLeagues()
                }
                .navigationBarItems(trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                })
            }
        }
    }
    
    private func fetchUserLeagues() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            errorMessage = "User not signed in"
            return
        }
        
        let db = Firestore.firestore()
        
        // Get leagues where user is either host or member
        db.collection("leagues")
            .whereField("hostUserId", isEqualTo: userId)
            .getDocuments { [self] (snapshot, error) in
                if let error = error {
                    print("Error fetching user's hosted leagues: \(error.localizedDescription)")
                    self.errorMessage = "Failed to load leagues"
                    self.isLoading = false
                    return
                }
                
                var userLeagues: [LeagueInfo] = []
                
                // Add hosted leagues
                if let documents = snapshot?.documents {
                    for document in documents {
                        let data = document.data()
                        let name = data["name"] as? String ?? "Unnamed League"
                        let league = LeagueInfo(id: document.documentID, name: name)
                        userLeagues.append(league)
                    }
                }
                
                // Also fetch leagues where user is a member
                db.collection("leagues")
                    .whereField("memberIds", arrayContains: userId)
                    .getDocuments { [self] (snapshot, error) in
                        isLoading = false
                        
                        if let error = error {
                            print("Error fetching user's member leagues: \(error.localizedDescription)")
                            errorMessage = "Failed to load leagues"
                            return
                        }
                        
                        // Add member leagues
                        if let documents = snapshot?.documents {
                            for document in documents {
                                let data = document.data()
                                let name = data["name"] as? String ?? "Unnamed League"
                                let leagueId = document.documentID
                                
                                // Only add if not already added (not a host)
                                if !userLeagues.contains(where: { $0.id == leagueId }) {
                                    let league = LeagueInfo(id: leagueId, name: name)
                                    userLeagues.append(league)
                                }
                            }
                        }
                        
                        self.leagues = userLeagues
                    }
            }
    }
}

// Renamed from League to LeagueInfo to avoid conflicts
struct LeagueInfo: Identifiable {
    let id: String
    let name: String
}

struct LeagueSubmissionView_Previews: PreviewProvider {
    static var previews: some View {
        LeagueSubmissionView(
            score: 85,
            course: "Armitage Golf Club",
            holeCount: 18,
            steps: 12345,
            distance: 5.2,
            calories: 430,
            onSubmit: { _ in }
        )
    }
}
