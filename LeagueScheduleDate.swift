import Firebase
import FirebaseFirestore

// Data model for a league date
struct LeagueScheduleDate: Codable, Identifiable {
    @DocumentID var id: String?
    let date: Date
    let location: String
    let courseName: String
    let confirmedCount: Int
    let maybeCount: Int
    let declinedCount: Int
    let teeTime: Date
    let notes: String?
    let isActive: Bool
    
    // Create Firestore dictionary
    func toDictionary() -> [String: Any] {
        return [
            "date": Timestamp(date: date),
            "location": location,
            "courseName": courseName,
            "confirmedCount": confirmedCount,
            "maybeCount": maybeCount,
            "declinedCount": declinedCount,
            "teeTime": Timestamp(date: teeTime),
            "notes": notes ?? "",
            "isActive": isActive
        ]
    }
    
    // Create from Firestore dictionary
    static func fromDictionary(_ data: [String: Any], id: String) -> LeagueScheduleDate? {
        guard let dateTimestamp = data["date"] as? Timestamp,
              let location = data["location"] as? String,
              let courseName = data["courseName"] as? String,
              let teeTimeTimestamp = data["teeTime"] as? Timestamp else {
            return nil
        }
        
        let confirmedCount = data["confirmedCount"] as? Int ?? 0
        let maybeCount = data["maybeCount"] as? Int ?? 0
        let declinedCount = data["declinedCount"] as? Int ?? 0
        let notes = data["notes"] as? String
        let isActive = data["isActive"] as? Bool ?? true
        
        return LeagueScheduleDate(
            id: id,
            date: dateTimestamp.dateValue(),
            location: location,
            courseName: courseName,
            confirmedCount: confirmedCount,
            maybeCount: maybeCount,
            declinedCount: declinedCount,
            teeTime: teeTimeTimestamp.dateValue(),
            notes: notes,
            isActive: isActive
        )
    }
}

// RSVP model for a specific date
struct DateRSVP: Codable, Identifiable {
    @DocumentID var id: String?
    let userId: String
    let dateId: String
    let status: String
    let note: String
    let timestamp: Date
    let username: String
    
    // Create Firestore dictionary
    func toDictionary() -> [String: Any] {
        return [
            "userId": userId,
            "dateId": dateId,
            "status": status,
            "note": note,
            "timestamp": Timestamp(date: timestamp),
            "username": username
        ]
    }
}

// League Date Service
class LeagueDateService {
    private let db = Firestore.firestore()
    
    // Create a new league date
    func createLeagueDate(leagueId: String, date: LeagueScheduleDate, completion: @escaping (Result<String, Error>) -> Void) {
        let leagueDatesRef = db.collection("leagues").document(leagueId).collection("dates")
        
        leagueDatesRef.addDocument(data: date.toDictionary()) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success("Date added successfully"))
            }
        }
    }
    
    // Get upcoming league dates
    func getUpcomingDates(leagueId: String, completion: @escaping (Result<[LeagueScheduleDate], Error>) -> Void) {
        let today = Calendar.current.startOfDay(for: Date())
        
        db.collection("leagues").document(leagueId).collection("dates")
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: today))
            .whereField("isActive", isEqualTo: true)
            .order(by: "date")
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let dates = documents.compactMap { doc in
                    LeagueScheduleDate.fromDictionary(doc.data(), id: doc.documentID)
                }
                
                completion(.success(dates))
            }
    }
    
    // Submit RSVP
    func submitRSVP(leagueId: String, rsvp: DateRSVP, completion: @escaping (Result<Void, Error>) -> Void) {
        // No need to check for optionals since userId and dateId are non-optional in the struct
        
        let batch = db.batch()
        
        // Save RSVP
        let rsvpRef = db.collection("leagues").document(leagueId)
            .collection("dates").document(rsvp.dateId)
            .collection("rsvps").document(rsvp.userId)
        
        batch.setData(rsvp.toDictionary(), forDocument: rsvpRef)
        
        // Update counts on the date document
        let dateRef = db.collection("leagues").document(leagueId)
            .collection("dates").document(rsvp.dateId)
        
        // Update counts based on RSVP status
        switch rsvp.status {
        case "attending":
            batch.updateData([
                "confirmedCount": FieldValue.increment(Int64(1))
            ], forDocument: dateRef)
        case "notAttending":
            batch.updateData([
                "declinedCount": FieldValue.increment(Int64(1))
            ], forDocument: dateRef)
        case "maybe":
            batch.updateData([
                "maybeCount": FieldValue.increment(Int64(1))
            ], forDocument: dateRef)
        default:
            break
        }
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // Get attendees for a date
    func getDateAttendees(leagueId: String, dateId: String, status: String? = nil, completion: @escaping (Result<[DateRSVP], Error>) -> Void) {
        var query: Query = db.collection("leagues").document(leagueId)
            .collection("dates").document(dateId)
            .collection("rsvps")
        
        if let status = status {
            query = query.whereField("status", isEqualTo: status)
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }
            
            let rsvps = documents.compactMap { doc -> DateRSVP? in
                let data = doc.data()
                
                guard let userId = data["userId"] as? String,
                      let dateId = data["dateId"] as? String,
                      let status = data["status"] as? String,
                      let username = data["username"] as? String,
                      let timestamp = data["timestamp"] as? Timestamp else {
                    return nil
                }
                
                let note = data["note"] as? String ?? ""
                
                return DateRSVP(
                    id: doc.documentID,
                    userId: userId,
                    dateId: dateId,
                    status: status,
                    note: note,
                    timestamp: timestamp.dateValue(),
                    username: username
                )
            }
            
            completion(.success(rsvps))
        }
    }
}
