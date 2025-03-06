//
//  LeagueService.swift
//  Aldo
//
//  Created by Andrew Katsifis on 1/26/25.
//

import FirebaseFirestore

class LeagueService {
    static let shared = LeagueService()
    private let db = Firestore.firestore()

    // MARK: - Check if League Name is Unique
    func isLeagueNameUnique(name: String, completion: @escaping (Bool) -> Void) {
        let leaguesRef = db.collection("leagues")
        
        leaguesRef.whereField("name", isEqualTo: name).getDocuments { snapshot, error in
            if let error = error {
                print("Error checking league name: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            if let snapshot = snapshot, snapshot.isEmpty {
                // League name is unique
                completion(true)
            } else {
                // League name already exists
                completion(false)
            }
        }
    }
    
    // MARK: - Create a New League (Updated to accept individual parameters)
    func createLeague(name: String, hostUserId: String, members: [String], course: String, schedule: String, completion: @escaping (Bool) -> Void) {
        // Create the league object
        let league = League(name: name, hostUserId: hostUserId, members: members, course: course, schedule: schedule, createdAt: Timestamp(date: Date()))

        // Check if league name is unique
        isLeagueNameUnique(name: league.name) { isUnique in
            if isUnique {
                // Add the league to Firestore
                self.db.collection("leagues").addDocument(data: league.toDictionary()) { error in
                    if let error = error {
                        print("Error creating league: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("League created successfully!")
                        completion(true)
                    }
                }
            } else {
                print("League name already exists.")
                completion(false)
            }
        }
    }
    
    // MARK: - Add Round to League
    func addRoundToLeague(leagueId: String, round: League.Round, completion: @escaping (Bool) -> Void) {
        let roundData: [String: Any] = [
            "number": round.number,
            "score": round.score,
            "createdAt": Timestamp(date: Date())
        ]
        
        db.collection("leagues").document(leagueId).collection("rounds").addDocument(data: roundData) { error in
            if let error = error {
                print("Error adding round: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Round added successfully!")
                completion(true)
            }
        }
    }
    
    // MARK: - Update Scores for a Round
    func updateScores(leagueId: String, roundId: String, score: League.Score, completion: @escaping (Bool) -> Void) {
        let scoreData: [String: Any] = [
            "userId": score.userId,
            "holeScores": score.holeScores,
            "updatedAt": Timestamp(date: Date())
        ]
        
        let scoresRef = db.collection("leagues").document(leagueId).collection("rounds").document(roundId).collection("scores").document(score.id.uuidString)
        scoresRef.setData(scoreData) { error in
            if let error = error {
                print("Error updating score: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Score updated successfully!")
                completion(true)
            }
        }
    }

    // MARK: - Fetch League Data
    func fetchLeagueData(leagueId: String, completion: @escaping (League?) -> Void) {
        db.collection("leagues").document(leagueId).getDocument { document, error in
            if let error = error {
                print("Error fetching league data: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let document = document, document.exists else {
                print("League not found")
                completion(nil)
                return
            }
            
            // Map Firestore data to League model
            let data = document.data()
            let league = League(
                id: document.documentID,
                name: data?["name"] as? String ?? "",
                hostUserId: data?["hostUserId"] as? String ?? "",
                members: data?["members"] as? [String] ?? [],
                course: data?["course"] as? String ?? "",
                schedule: data?["schedule"] as? String ?? "",
                createdAt: data?["createdAt"] as? Timestamp ?? Timestamp(date: Date()) // Ensure valid Timestamp
            )
            completion(league)
        }
    }
}
