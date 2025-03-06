//
//  FirestoreManager.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/5/25.
//


//
//  FirestoreManager.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/4/25.
//
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

class FirestoreManager {
    static let shared = FirestoreManager()
    private let db: Firestore
    
    private init() {
        // Get the Firestore instance but don't configure it directly
        // The configuration will be done in AldoApp.swift before FirebaseApp.configure()
        db = Firestore.firestore()
    }
    
    // Method to configure Firestore settings - call this BEFORE Firebase initialization
    static func configureFirestore() {
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        Firestore.firestore().settings = settings
    }
    
    // MARK: - Score Management
    
    func saveScoreOffline(score: Models.User.Score, userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Create a new document reference with auto-generated ID
        let scoreRef = db.collection("users").document(userId).collection("pendingScores").document()
        
        // Convert score to dictionary
        let scoreData: [String: Any] = [
            "id": score.id,
            "course": score.course,
            "score": score.score,
            "date": score.date,
            "holesPlayed": score.holesPlayed,
            "steps": score.steps ?? 0,
            "distance": score.distance ?? 0.0,
            "caloriesBurned": score.caloriesBurned ?? 0.0,
            "syncStatus": "pending"
        ]
        
        // Set the data
        scoreRef.setData(scoreData) { error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            completion(.success(scoreRef.documentID))
        }
    }
    
    func syncPendingScores(userId: String, completion: @escaping (Result<Int, Error>) -> Void) {
        // Get all pending scores
        db.collection("users").document(userId).collection("pendingScores")
            .whereField("syncStatus", isEqualTo: "pending")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    completion(.success(0)) // No pending scores to sync
                    return
                }
                
                var syncedCount = 0
                let totalCount = documents.count
                let group = DispatchGroup()
                var syncError: Error?
                
                // Fetch the user document to get the current scores array
                group.enter()
                self.db.collection("users").document(userId).getDocument { userSnapshot, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        syncError = error
                        return
                    }
                    
                    guard let userData = userSnapshot?.data() else {
                        syncError = NSError(domain: "FirestoreManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"])
                        return
                    }
                    
                    // Get current scores
                    var userScores: [[String: Any]] = []
                    if let currentScores = userData["scores"] as? [[String: Any]] {
                        userScores = currentScores
                    }
                    
                    // Add pending scores to the user's scores array
                    for document in documents {
                        group.enter()
                        let scoreData = document.data()
                        var scoreDict: [String: Any] = [:]
                        
                        // Copy relevant fields to the score dictionary
                        for key in ["id", "course", "score", "date", "holesPlayed", "steps", "distance", "caloriesBurned"] {
                            if let value = scoreData[key] {
                                scoreDict[key] = value
                            }
                        }
                        
                        // Add to user's scores
                        userScores.append(scoreDict)
                        
                        // Mark this pending score as synced
                        document.reference.updateData(["syncStatus": "synced"]) { error in
                            defer { group.leave() }
                            
                            if let error = error {
                                print("Error marking score as synced: \(error.localizedDescription)")
                                return
                            }
                            
                            syncedCount += 1
                        }
                    }
                    
                    // Update the user document with the new scores array
                    self.db.collection("users").document(userId).updateData([
                        "scores": userScores
                    ]) { error in
                        if let error = error {
                            syncError = error
                        }
                    }
                }
                
                // When all operations are complete
                group.notify(queue: .main) {
                    if let syncError = syncError {
                        completion(.failure(syncError))
                    } else {
                        completion(.success(syncedCount))
                    }
                }
            }
    }
    
    func cleanupSyncedScores(userId: String, completion: @escaping (Result<Int, Error>) -> Void) {
        // Find all synced scores older than 7 days
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        db.collection("users").document(userId).collection("pendingScores")
            .whereField("syncStatus", isEqualTo: "synced")
            .whereField("date", isLessThan: oneWeekAgo)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    completion(.success(0)) // No old scores to clean up
                    return
                }
                
                let batch = self.db.batch()
                
                // Add delete operations to batch
                for document in documents {
                    batch.deleteDocument(document.reference)
                }
                
                // Commit batch
                batch.commit { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(documents.count))
                    }
                }
            }
    }
    
    // MARK: - Network state monitoring
    
    func addNetworkListener(onNetworkAvailable: @escaping () -> Void) {
        db.collection("users").document("networkTest").addSnapshotListener { _, error in
            if error == nil {
                // If we can successfully listen to Firestore, we have network connectivity
                onNetworkAvailable()
            }
        }
    }
}
