//// MARK: - Enhanced League Model with Extended Properties
//
////
//// struct League: Identifiable, Codable {
////    @DocumentID var id: String?
////    var name: String
////    var hostUserId: String
////    var members: [String]
////    var course: String
////    var schedule: String
////    var createdAt: Timestamp
////    var totalRounds: Int = 0
////    var leagueStandings: [LeagueStanding] = []
////    var nextScheduledDate: Timestamp?
////    var isActive: Bool = true
//    
//    // Create dictionary for Firestore
////    func toDictionary() -> [String: Any] {
////        var dict: [String: Any] = [
////            "name": name,
////            "hostUserId": hostUserId,
////            "members": members,
////            "course": course,
////          "schedule": schedule,
////          "createdAt": createdAt,
////          "totalRounds": totalRounds,
////          "isActive": isActive
////      ]
////
//        if let nextScheduledDate = nextScheduledDate {
//            dict["nextScheduledDate"] = nextScheduledDate
//        }
//        
//        return dict
//    }
//    
//    // Parse from Firestore dictionary
//    static func fromDictionary(_ data: [String: Any], id: String) -> League? {
//        guard
//            let name = data["name"] as? String,
//            let hostUserId = data["hostUserId"] as? String,
//            let members = data["members"] as? [String],
//            let course = data["course"] as? String,
//            let schedule = data["schedule"] as? String,
//            let createdAt = data["createdAt"] as? Timestamp
//        else {
//            return nil
//        }
//        
//        let totalRounds = data["totalRounds"] as? Int ?? 0
//        let nextScheduledDate = data["nextScheduledDate"] as? Timestamp
//        let isActive = data["isActive"] as? Bool ?? true
//        
//        var league = League(
//            id: id,
//            name: name,
//            hostUserId: hostUserId,
//            members: members,
//            course: course,
//            schedule: schedule,
//            createdAt: createdAt,
//            totalRounds: totalRounds,
//            isActive: isActive
//        )
//        
//        league.nextScheduledDate = nextScheduledDate
//        
//        return league
//    }
//}
//
//// MARK: - League Standing Model
//
//struct LeagueStanding: Identifiable, Codable {
//    var id: String // User ID
//    var username: String
//    var totalScore: Int
//    var roundsPlayed: Int
//    var averageScore: Double
//    var profilePicture: String?
//    
//    // For sorting
//    static func < (lhs: LeagueStanding, rhs: LeagueStanding) -> Bool {
//        return lhs.averageScore < rhs.averageScore
//    }
//}
//
//// MARK: - Weekly Attendance Record
//
//struct WeeklyAttendance: Identifiable, Codable {
//    @DocumentID var id: String?
//    var userId: String
//    var username: String
//    var weekStartDate: Date
//    var isAttending: Bool
//    var notes: String?
//    var confirmedAt: Date?
//    
//    // Create dictionary for Firestore
//    func toDictionary() -> [String: Any] {
//        var dict: [String: Any] = [
//            "userId": userId,
//            "username": username,
//            "weekStartDate": Timestamp(date: weekStartDate),
//            "isAttending": isAttending
//        ]
//        
//        if let notes = notes {
//            dict["notes"] = notes
//        }
//        
//        if let confirmedAt = confirmedAt {
//            dict["confirmedAt"] = Timestamp(date: confirmedAt)
//        }
//        
//        return dict
//    }
//}
//
//// MARK: - Weekly Score Record
//
//struct WeeklyScore: Identifiable, Codable {
//    @DocumentID var id: String?
//    var userId: String
//    var username: String
//    var weekStartDate: Date
//    var score: Int
//    var courseId: String?
//    var courseName: String
//    var hole9Score: Int?
//    var hole18Score: Int?
//    var playedOn: Date
//    var notes: String?
//    
//    // Create dictionary for Firestore
//    func toDictionary() -> [String: Any] {
//        var dict: [String: Any] = [
//            "userId": userId,
//            "username": username,
//            "weekStartDate": Timestamp(date: weekStartDate),
//            "score": score,
//            "courseName": courseName,
//            "playedOn": Timestamp(date: playedOn)
//        ]
//        
//        if let courseId = courseId {
//            dict["courseId"] = courseId
//        }
//        
//        if let hole9Score = hole9Score {
//            dict["hole9Score"] = hole9Score
//        }
//        
//        if let hole18Score = hole18Score {
//            dict["hole18Score"] = hole18Score
//        }
//        
//        if let notes = notes {
//            dict["notes"] = notes
//        }
//        
//        return dict
//    }
//}
//
//// MARK: - League Message Model
//
//struct LeagueMessage: Identifiable, Codable {
//    @DocumentID var id: String?
//    var userId: String
//    var username: String
//    var text: String
//    var timestamp: Date
//    var imageUrl: String?
//    var isRsvp: Bool
//    var rsvpStatus: String?
//    var isScoreSubmission: Bool = false
//    var submittedScore: Int?
//    var profilePictureUrl: String?
//    
//    // Create dictionary for Firestore
//    func toDictionary() -> [String: Any] {
//        var dict: [String: Any] = [
//            "userId": userId,
//            "username": username,
//            "text": text,
//            "timestamp": Timestamp(date: timestamp),
//            "isRsvp": isRsvp,
//            "isScoreSubmission": isScoreSubmission
//        ]
//        
//        if let imageUrl = imageUrl {
//            dict["imageUrl"] = imageUrl
//        }
//        
//        if let rsvpStatus = rsvpStatus {
//            dict["rsvpStatus"] = rsvpStatus
//        }
//        
//        if let submittedScore = submittedScore {
//            dict["submittedScore"] = submittedScore
//        }
//        
//        if let profilePictureUrl = profilePictureUrl {
//            dict["profilePictureUrl"] = profilePictureUrl
//        }
//        
//        return dict
//    }
//}
//
//// MARK: - Enhanced LeagueService
//
//class LeagueService {
//    static let shared = LeagueService()
//    private let db = Firestore.firestore()
//    
//    // MARK: - Fetch User's Leagues
//    
//    func fetchUserLeagues(forUser userId: String, completion: @escaping (Result<[League], Error>) -> Void) {
//        // Fetch leagues where user is host
//        db.collection("leagues")
//            .whereField("hostUserId", isEqualTo: userId)
//            .getDocuments { [weak self] (snapshot, error) in
//                guard let self = self else { return }
//                
//                if let error = error {
//                    completion(.failure(error))
//                    return
//                }
//                
//                var userLeagues: [League] = []
//                
//                if let documents = snapshot?.documents {
//                    for document in documents {
//                        if let league = League.fromDictionary(document.data(), id: document.documentID) {
//                            userLeagues.append(league)
//                        }
//                    }
//                }
//                
//                // Fetch leagues where user is a member
//                self.db.collection("leagues")
//                    .whereField("members", arrayContains: userId)
//                    .getDocuments { (snapshot, error) in
//                        if let error = error {
//                            completion(.failure(error))
//                            return
//                        }
//                        
//                        if let documents = snapshot?.documents {
//                            for document in documents {
//                                // Only add if not already added as host
//                                if !userLeagues.contains(where: { $0.id == document.documentID }) {
//                                    if let league = League.fromDictionary(document.data(), id: document.documentID) {
//                                        userLeagues.append(league)
//                                    }
//                                }
//                            }
//                        }
//                        
//                        completion(.success(userLeagues))
//                    }
//            }
//    }
//    
//    // MARK: - Fetch League Standings
//    
//    func fetchLeagueStandings(leagueId: String, completion: @escaping (Result<[LeagueStanding], Error>) -> Void) {
//        // Fetch all rounds for this league
//        db.collection("leagues").document(leagueId).collection("rounds")
//            .getDocuments { (snapshot, error) in
//                if let error = error {
//                    completion(.failure(error))
//                    return
//                }
//                
//                guard let documents = snapshot?.documents else {
//                    completion(.success([]))
//                    return
//                }
//                
//                // First, collect score data by user
//                var userScores: [String: [Int]] = [:]
//                var usernames: [String: String] = [:]
//                var profilePics: [String: String] = [:]
//                
//                // Process each round
//                let dispatchGroup = DispatchGroup()
//                
//                for document in documents {
//                    let roundData = document.data()
//                    guard let userId = roundData["userId"] as? String,
//                          let score = roundData["score"] as? Int else {
//                        continue
//                    }
//                    
//                    // Store the score
//                    if userScores[userId] == nil {
//                        userScores[userId] = []
//                    }
//                    userScores[userId]?.append(score)
//                    
//                    // If we don't have the username yet, fetch user details
//                    if usernames[userId] == nil {
//                        dispatchGroup.enter()
//                        
//                        self.db.collection("users").document(userId).getDocument { snapshot, error in
//                            defer { dispatchGroup.leave() }
//                            
//                            if let error = error {
//                                print("Error fetching user data: \(error.localizedDescription)")
//                                return
//                            }
//                            
//                            if let userData = snapshot?.data() {
//                                usernames[userId] = userData["username"] as? String ?? "Unknown"
//                                profilePics[userId] = userData["profilePicture"] as? String
//                            }
//                        }
//                    }
//                }
//                
//                // Wait for all user data to be fetched
//                dispatchGroup.notify(queue: .main) {
//                    // Create standings
//                    var standings: [LeagueStanding] = []
//                    
//                    for (userId, scores) in userScores {
//                        let totalScore = scores.reduce(0, +)
//                        let roundsPlayed = scores.count
//                        let averageScore = roundsPlayed > 0 ? Double(totalScore) / Double(roundsPlayed) : 0
//                        
//                        let standing = LeagueStanding(
//                            id: userId,
//                            username: usernames[userId] ?? "Unknown",
//                            totalScore: totalScore,
//                            roundsPlayed: roundsPlayed,
//                            averageScore: averageScore,
//                            profilePicture: profilePics[userId]
//                        )
//                        
//                        standings.append(standing)
//                    }
//                    
//                    // Sort by average score (lower is better)
//                    standings.sort()
//                    
//                    completion(.success(standings))
//                }
//            }
//    }
//    
//    // MARK: - Weekly Attendance Management
//    
//    func setWeeklyAttendance(leagueId: String, attendance: WeeklyAttendance, completion: @escaping (Result<Void, Error>) -> Void) {
//        let attendanceRef = db.collection("leagues").document(leagueId)
//            .collection("weeklyAttendance").document(attendance.userId)
//        
//        attendanceRef.setData(attendance.toDictionary()) { error in
//            if let error = error {
//                completion(.failure(error))
//            } else {
//                completion(.success(()))
//            }
//        }
//    }
//    
//    func fetchWeeklyAttendance(leagueId: String, forWeek date: Date, completion: @escaping (Result<[WeeklyAttendance], Error>) -> Void) {
//        // Get start of week for the given date
//        let calendar = Calendar.current
//        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
//        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
//        
//        db.collection("leagues").document(leagueId)
//            .collection("weeklyAttendance")
//            .whereField("weekStartDate", isGreaterThanOrEqualTo: Timestamp(date: startOfWeek))
//            .whereField("weekStartDate", isLessThan: Timestamp(date: endOfWeek))
//            .getDocuments { snapshot, error in
//                if let error = error {
//                    completion(.failure(error))
//                    return
//                }
//                
//                guard let documents = snapshot?.documents else {
//                    completion(.success([]))
//                    return
//                }
//                
//                let attendances = documents.compactMap { doc -> WeeklyAttendance? in
//                    let data = doc.data()
//                    
//                    guard let userId = data["userId"] as? String,
//                          let username = data["username"] as? String,
//                          let weekStartTimestamp = data["weekStartDate"] as? Timestamp,
//                          let isAttending = data["isAttending"] as? Bool else {
//                        return nil
//                    }
//                    
//                    let notes = data["notes"] as? String
//                    let confirmedAtTimestamp = data["confirmedAt"] as? Timestamp
//                    
//                    return WeeklyAttendance(
//                        id: doc.documentID,
//                        userId: userId,
//                        username: username,
//                        weekStartDate: weekStartTimestamp.dateValue(),
//                        isAttending: isAttending,
//                        notes: notes,
//                        confirmedAt: confirmedAtTimestamp?.dateValue()
//                    )
//                }
//                
//                completion(.success(attendances))
//            }
//    }
//    
//    // MARK: - Weekly Score Management
//    
//    func submitWeeklyScore(leagueId: String, score: WeeklyScore, completion: @escaping (Result<Void, Error>) -> Void) {
//        let scoreRef = db.collection("leagues").document(leagueId)
//            .collection("weeklyScores").document()
//        
//        scoreRef.setData(score.toDictionary()) { error in
//            if let error = error {
//                completion(.failure(error))
//                return
//            }
//            
//            // Also add round to overall league rounds collection for standings
//            let roundRef = self.db.collection("leagues").document(leagueId)
//                .collection("rounds").document()
//            
//            let roundData: [String: Any] = [
//                "userId": score.userId,
//                "score": score.score,
//                "date": Timestamp(date: score.playedOn),
//                "course": score.courseName
//            ]
//            
//            roundRef.setData(roundData) { error in
//                if let error = error {
//                    completion(.failure(error))
//                } else {
//                    // Also increment totalRounds counter
//                    self.db.collection("leagues").document(leagueId)
//                        .updateData(["totalRounds": FieldValue.increment(Int64(1))]) { error in
//                            if let error = error {
//                                print("Warning: Failed to increment totalRounds: \(error.localizedDescription)")
//                            }
//                            
//                            // Also post a message to the league chat
//                            let message = LeagueMessage(
//                                userId: score.userId,
//                                username: score.username,
//                                text: "I just submitted a score of \(score.score) at \(score.courseName)!",
//                                timestamp: Date(),
//                                isRsvp: false,
//                                isScoreSubmission: true,
//                                submittedScore: score.score
//                            )
//                            
//                            self.postLeagueMessage(leagueId: leagueId, message: message) { _ in
//                                // We'll continue regardless of message posting result
//                                completion(.success(()))
//                            }
//                        }
//                }
//            }
//        }
//    }
//    
//    func fetchWeeklyScores(leagueId: String, forWeek date: Date, completion: @escaping (Result<[WeeklyScore], Error>) -> Void) {
//        // Get start of week for the given date
//        let calendar = Calendar.current
//        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
//        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
//        
//        db.collection("leagues").document(leagueId)
//            .collection("weeklyScores")
//            .whereField("weekStartDate", isGreaterThanOrEqualTo: Timestamp(date: startOfWeek))
//            .whereField("weekStartDate", isLessThan: Timestamp(date: endOfWeek))
//            .getDocuments { snapshot, error in
//                if let error = error {
//                    completion(.failure(error))
//                    return
//                }
//                
//                guard let documents = snapshot?.documents else {
//                    completion(.success([]))
//                    return
//                }
//                
//                let scores = documents.compactMap { doc -> WeeklyScore? in
//                    let data = doc.data()
//                    
//                    guard let userId = data["userId"] as? String,
//                          let username = data["username"] as? String,
//                          let weekStartTimestamp = data["weekStartDate"] as? Timestamp,
//                          let score = data["score"] as? Int,
//                          let courseName = data["courseName"] as? String,
//                          let playedOnTimestamp = data["playedOn"] as? Timestamp else {
//                        return nil
//                    }
//                    
//                    let courseId = data["courseId"] as? String
//                    let hole9Score = data["hole9Score"] as? Int
//                    let hole18Score = data["hole18Score"] as? Int
//                    let notes = data["notes"] as? String
//                    
//                    return WeeklyScore(
//                        id: doc.documentID,
//                        userId: userId,
//                        username: username,
//                        weekStartDate: weekStartTimestamp.dateValue(),
//                        score: score,
//                        courseId: courseId,
//                        courseName: courseName,
//                        hole9Score: hole9Score,
//                        hole18Score: hole18Score,
//                        playedOn: playedOnTimestamp.dateValue(),
//                        notes: notes
//                    )
//                }
//                
//                completion(.success(scores))
//            }
//    }
//    
//    // MARK: - League Chat
//    
//    func postLeagueMessage(leagueId: String, message: LeagueMessage, completion: @escaping (Result<Void, Error>) -> Void) {
//        db.collection("leagues").document(leagueId)
//            .collection("messages").document()
//            .setData(message.toDictionary()) { error in
//                if let error = error {
//                    completion(.failure(error))
//                } else {
//                    completion(.success(()))
//                }
//            }
//    }
//    
//    func fetchLeagueMessages(leagueId: String, limit: Int = 50, completion: @escaping (Result<[LeagueMessage], Error>) -> Void) {
//        db.collection("leagues").document(leagueId)
//            .collection("messages")
//            .order(by: "timestamp", descending: true)
//            .limit(to: limit)
//            .getDocuments { snapshot, error in
//                if let error = error {
//                    completion(.failure(error))
//                    return
//                }
//                
//                guard let documents = snapshot?.documents else {
//                    completion(.success([]))
//                    return
//                }
//                
//                let messages = documents.compactMap { doc -> LeagueMessage? in
//                    let data = doc.data()
//                    
//                    guard let userId = data["userId"] as? String,
//                          let username = data["username"] as? String,
//                          let text = data["text"] as? String,
//                          let timestampData = data["timestamp"] as? Timestamp else {
//                        return nil
//                    }
//                    
//                    let imageUrl = data["imageUrl"] as? String
//                    let isRsvp = data["isRsvp"] as? Bool ?? false
//                    let rsvpStatus = data["rsvpStatus"] as? String
//                    let isScoreSubmission = data["isScoreSubmission"] as? Bool ?? false
//                    let submittedScore = data["submittedScore"] as? Int
//                    let profilePictureUrl = data["profilePictureUrl"] as? String
//                    
//                    return LeagueMessage(
//                        id: doc.documentID,
//                        userId: userId,
//                        username: username,
//                        text: text,
//                        timestamp: timestampData.dateValue(),
//                        imageUrl: imageUrl,
//                        isRsvp: isRsvp,
//                        rsvpStatus: rsvpStatus,
//                        isScoreSubmission: isScoreSubmission,
//                        submittedScore: submittedScore,
//                        profilePictureUrl: profilePictureUrl
//                    )
//                }
//                
//                // Return sorted by timestamp, newest first
//                completion(.success(messages.sorted(by: { $0.timestamp > $1.timestamp })))
//            }
//    }
//    
//    // MARK: - Listen for Messages
//    
//    func listenForMessages(leagueId: String, completion: @escaping (Result<[LeagueMessage], Error>) -> Void) -> ListenerRegistration {
//        return db.collection("leagues").document(leagueId)
//            .collection("messages")
//            .order(by: "timestamp", descending: true)
//            .limit(to: 50)
//            .addSnapshotListener { snapshot, error in
//                if let error = error {
//                    completion(.failure(error))
//                    return
//                }
//                
//                guard let documents = snapshot?.documents else {
//                    completion(.success([]))
//                    return
//                }
//                
//                let messages = documents.compactMap { doc -> LeagueMessage? in
//                    let data = doc.data()
//                    
//                    guard let userId = data["userId"] as? String,
//                          let username = data["username"] as? String,
//                          let text = data["text"] as? String,
//                          let timestampData = data["timestamp"] as? Timestamp else {
//                        return nil
//                    }
//                    
//                    let imageUrl = data["imageUrl"] as? String
//                    let isRsvp = data["isRsvp"] as? Bool ?? false
//                    let rsvpStatus = data["rsvpStatus"] as? String
//                    let isScoreSubmission = data["isScoreSubmission"] as? Bool ?? false
//                    let submittedScore = data["submittedScore"] as? Int
//                    let profilePictureUrl = data["profilePictureUrl"] as? String
//                    
//                    //return LeagueMessage(
//                    //  id: doc.documentID,
//                    //  userId: userId,
//                    //  username: username,
//                    //  text: text,
//                    //  timestamp: timestampData.dateValue(),
//                    //  imageUrl: imageUrl,
//                    //  isRsvp: isRsvp,
//                    //  rsvpStatus: rsvpStatus,
//                    //  isScoreSubmission: isScoreSubmission,
//                        submittedScore: submittedScore,
//                        profilePictureUrl: profilePictureUrl
//                        //)
//                    // }
//                //
//                // Return sorted by timestamp, newest first
//                // completion(.success(messages.sorted(by: { $0.timestamp > $1.timestamp })))
//                //}
//        //  }
//    //}
