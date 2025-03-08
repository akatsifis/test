//import SwiftUI
//import FirebaseFirestore
//
//struct LeagueDetailView: View {
//    var league: EnhancedLeague
//    @State private var rounds: [LeagueRound] = []
//    
//    var body: some View {
//        VStack {
//            Text(league.name)
//                .font(.title)
//                .padding()
//            
//            if rounds.isEmpty {
//                Text("No rounds yet.")
//                    .foregroundColor(.gray)
//                    .padding()
//            } else {
//                List(rounds, id: \.id) { round in
//                    VStack(alignment: .leading) {
//                        Text("Round \(round.number)")
//                            .font(.headline)
//                        Text("Score: \(round.score)")
//                            .font(.subheadline)
//                        Text("Date: \(round.createdAt.dateValue(), formatter: dateFormatter)")
//                            .font(.caption)
//                    }
//                    .padding(.vertical, 4)
//                }
//                .listStyle(PlainListStyle())
//            }
//            
//            Button("Add Round") {
//                addNewRound()
//            }
//            .font(.title2)
//            .padding()
//            .background(Color.blue)
//            .foregroundColor(.white)
//            .cornerRadius(10)
//            .shadow(radius: 5)
//            .padding()
//            
//            Spacer()
//        }
//        .onAppear {
//            fetchRounds()
//        }
//    }
//    
//    // Fetch rounds from Firestore and map them to LeagueRound objects.
//    private func fetchRounds() {
//        let db = Firestore.firestore()
//        db.collection("leagues")
//            .document(league.id)
//            .collection("rounds")
//            .order(by: "number")
//            .getDocuments { snapshot, error in
//                if let error = error {
//                    print("Error fetching rounds: \(error.localizedDescription)")
//                } else {
//                    var fetchedRounds: [LeagueRound] = []
//                    snapshot?.documents.forEach { doc in
//                        let data = doc.data()
//                        let number = data["number"] as? Int ?? 0
//                        let score = data["score"] as? Int ?? 0
//                        let createdAt = data["createdAt"] as? Timestamp ?? Timestamp(date: Date())
//                        let id = doc.documentID
//                        let round = LeagueRound(id: id, number: number, score: score, createdAt: createdAt)
//                        fetchedRounds.append(round)
//                    }
//                    rounds = fetchedRounds
//                }
//            }
//    }
//    
//    // Create a new round and add it to Firestore.
//    private func addNewRound() {
//        let newRoundNumber = (rounds.last?.number ?? 0) + 1
//        let newRound = LeagueRound(id: "", number: newRoundNumber, score: 0, createdAt: Timestamp(date: Date()))
//        addRoundToLeague(leagueId: league.id, round: newRound)
//    }
//    
//    private func addRoundToLeague(leagueId: String, round: LeagueRound) {
//        let roundData: [String: Any] = [
//            "number": round.number,
//            "score": round.score,
//            "createdAt": round.createdAt
//        ]
//        
//        let db = Firestore.firestore()
//        db.collection("leagues")
//            .document(leagueId)
//            .collection("rounds")
//            .addDocument(data: roundData) { error in
//                if let error = error {
//                    print("Error adding round: \(error.localizedDescription)")
//                } else {
//                    print("Round added successfully!")
//                    fetchRounds() // Refresh rounds after adding.
//                }
//            }
//    }
//}
//
//// Date formatter for displaying round creation dates.
//private let dateFormatter: DateFormatter = {
//    let formatter = DateFormatter()
//    formatter.dateStyle = .short
//    formatter.timeStyle = .short
//    return formatter
//}()
//
//struct LeagueDetailView_Previews: PreviewProvider {
//    static var previews: some View {
//        LeagueDetailView(league: EnhancedLeague(
//            id: "1",
//            name: "Golf League",
//            hostUserId: "user123",
//            members: ["user123", "user456"],
//            course: "Course A",
//            schedule: "Weekly",
//            playDay: .monday,
//            createdAt: Timestamp(date: Date())
//        ))
//    }
//}
