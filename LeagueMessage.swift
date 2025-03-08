// MARK: - Models for LeagueChat

import Foundation
import SwiftUI
import FirebaseFirestore

// Enhanced League Message model with additional properties
struct LeagueMessage: Identifiable {
    let id: String
    let userId: String
    let username: String
    let text: String
    let timestamp: Date
    let imageUrl: String?
    let isRSVP: Bool
    let rsvpStatus: String?
    let isScoreSubmission: Bool
    let submittedScore: Int?
    let profilePictureUrl: String?
    var isPinned: Bool
}

// RSVP Status Enum
enum RSVPStatus: String, CaseIterable, Identifiable {
    case attending
    case notAttending
    case maybe
    
    var id: String { self.rawValue }
    
    var title: String {
        switch self {
        case .attending: return "Yes, I'll be there"
        case .notAttending: return "No, I can't make it"
        case .maybe: return "Maybe"
        }
    }
    
    var icon: String {
        switch self {
        case .attending: return "checkmark.circle.fill"
        case .notAttending: return "xmark.circle.fill"
        case .maybe: return "questionmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .attending: return .green
        case .notAttending: return .red
        case .maybe: return .orange
        }
    }
}

// Attachment option enum
enum AttachmentOption {
    case photo, location, poll
    
    var title: String {
        switch self {
        case .photo: return "Photo"
        case .location: return "Location"
        case .poll: return "Poll"
        }
    }
}

// League Chat Date model - named differently to avoid conflicts
struct LeagueChatDate: Identifiable, Hashable {
    let id: String
    let date: Date
    let location: String
    let confirmedCount: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: LeagueChatDate, rhs: LeagueChatDate) -> Bool {
        return lhs.id == rhs.id
    }
}
