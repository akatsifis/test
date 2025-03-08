import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Enhanced League Model
struct EnhancedLeague: Identifiable {
    var id: String
    var name: String
    var hostUserId: String
    var members: [String]
    var course: String
    var schedule: String
    var playDay: WeekDay
    var createdAt: Timestamp
    var totalRounds: Int = 0
    var nextScheduledDate: Timestamp?
    var isActive: Bool = true
    
    // Create dictionary for Firestore
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "hostUserId": hostUserId,
            "members": members,
            "course": course,
            "schedule": schedule,
            "playDay": playDay.rawValue,
            "createdAt": createdAt,
            "totalRounds": totalRounds,
            "isActive": isActive
        ]
        
        if let nextScheduledDate = nextScheduledDate {
            dict["nextScheduledDate"] = nextScheduledDate
        }
        
        return dict
    }
    
    // Parse from Firestore dictionary
    static func fromDictionary(_ data: [String: Any], id: String) -> EnhancedLeague? {
        guard
            let name = data["name"] as? String,
            let hostUserId = data["hostUserId"] as? String,
            let members = data["members"] as? [String],
            let course = data["course"] as? String,
            let schedule = data["schedule"] as? String,
            let createdAt = data["createdAt"] as? Timestamp
        else {
            return nil
        }
        
        // Handle playDay with a default fallback
        let playDayString = data["playDay"] as? String ?? "Monday"
        let playDay = WeekDay.allCases.first(where: { $0.rawValue == playDayString }) ?? .monday
        
        let totalRounds = data["totalRounds"] as? Int ?? 0
        let nextScheduledDate = data["nextScheduledDate"] as? Timestamp
        let isActive = data["isActive"] as? Bool ?? true
        
        var league = EnhancedLeague(
            id: id,
            name: name,
            hostUserId: hostUserId,
            members: members,
            course: course,
            schedule: schedule,
            playDay: playDay,
            createdAt: createdAt,
            totalRounds: totalRounds,
            isActive: isActive
        )
        
        league.nextScheduledDate = nextScheduledDate
        
        return league
    }
}

// MARK: - League Standing Model
struct LeagueStanding: Identifiable {
    var id: String // User ID
    var username: String
    var totalScore: Int
    var roundsPlayed: Int
    var averageScore: Double
    var profilePicture: String?
    
    // For sorting
    static func < (lhs: LeagueStanding, rhs: LeagueStanding) -> Bool {
        return lhs.averageScore < rhs.averageScore
    }
}

// MARK: - Weekly Attendance Record
struct WeeklyAttendance: Identifiable {
    var id: String
    var userId: String
    var username: String
    var weekStartDate: Date
    var isAttending: Bool
    var notes: String?
    var confirmedAt: Date?
    
    // Create dictionary for Firestore
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "username": username,
            "weekStartDate": Timestamp(date: weekStartDate),
            "isAttending": isAttending
        ]
        
        if let notes = notes {
            dict["notes"] = notes
        }
        
        if let confirmedAt = confirmedAt {
            dict["confirmedAt"] = Timestamp(date: confirmedAt)
        }
        
        return dict
    }
}

// MARK: - Weekly Score Record
struct WeeklyScore: Identifiable {
    var id: String
    var userId: String
    var username: String
    var weekStartDate: Date
    var score: Int
    var courseId: String?
    var courseName: String
    var hole9Score: Int?
    var hole18Score: Int?
    var playedOn: Date
    var notes: String?
    
    // Create dictionary for Firestore
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "username": username,
            "weekStartDate": Timestamp(date: weekStartDate),
            "score": score,
            "courseName": courseName,
            "playedOn": Timestamp(date: playedOn)
        ]
        
        if let courseId = courseId {
            dict["courseId"] = courseId
        }
        
        if let hole9Score = hole9Score {
            dict["hole9Score"] = hole9Score
        }
        
        if let hole18Score = hole18Score {
            dict["hole18Score"] = hole18Score
        }
        
        if let notes = notes {
            dict["notes"] = notes
        }
        
        return dict
    }
}

// MARK: - Enhanced League Message Model
struct EnhancedLeagueMessage: Identifiable {
    var id: String
    var userId: String
    var username: String
    var text: String
    var timestamp: Date
    var imageUrl: String?
    var isRsvp: Bool
    var rsvpStatus: String?
    var isScoreSubmission: Bool = false
    var submittedScore: Int?
    var profilePictureUrl: String?
    
    // Create dictionary for Firestore
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "username": username,
            "text": text,
            "timestamp": Timestamp(date: timestamp),
            "isRsvp": isRsvp,
            "isScoreSubmission": isScoreSubmission
        ]
        
        if let imageUrl = imageUrl {
            dict["imageUrl"] = imageUrl
        }
        
        if let rsvpStatus = rsvpStatus {
            dict["rsvpStatus"] = rsvpStatus
        }
        
        if let submittedScore = submittedScore {
            dict["submittedScore"] = submittedScore
        }
        
        if let profilePictureUrl = profilePictureUrl {
            dict["profilePictureUrl"] = profilePictureUrl
        }
        
        return dict
    }
}
