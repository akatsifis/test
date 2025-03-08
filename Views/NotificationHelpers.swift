// NotificationHelpers.swift
import Foundation
import Firebase
import FirebaseFirestore

// Extension methods for creating notifications in different contexts

// AuthenticationManager Extension
extension AuthenticationManager {
    // Add to the file where you handle friend requests
    func sendFriendRequestNotification(to userId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Try to get the sender's username
        let db = Firestore.firestore()
        db.collection("users").document(currentUserId).getDocument { snapshot, error in
            var username = "Someone"
            
            if let data = snapshot?.data(), let name = data["username"] as? String {
                username = name
            }
            
            // Create the notification
            NotificationManager.shared.createNotification(
                for: userId,
                title: "New Friend Request",
                message: "\(username) sent you a friend request",
                type: .friendRequest,
                relatedId: currentUserId
            )
        }
    }
}

// FriendsListView Extension
// Add this to your FriendsListView or where you handle accepting friend requests
extension FriendsListView {
    func sendFriendRequestAcceptedNotification(to userId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Try to get the username
        let db = Firestore.firestore()
        db.collection("users").document(currentUserId).getDocument { snapshot, error in
            var username = "Someone"
            
            if let data = snapshot?.data(), let name = data["username"] as? String {
                username = name
            }
            
            // Create the notification
            NotificationManager.shared.createNotification(
                for: userId,
                title: "Friend Request Accepted",
                message: "\(username) accepted your friend request",
                type: .friendRequest,
                relatedId: currentUserId
            )
        }
    }
}

// UserService Extension
extension UserService {
    // Call this after saving a score
    func sendScoreNotifications(score: Models.User.Score) {
        guard let currentUser = self.currentUser else { return }
        
        // Only notify friends
        for friendId in currentUser.friends {
            NotificationManager.shared.createNotification(
                for: friendId,
                title: "New Score Posted",
                message: "\(currentUser.username) scored \(score.score) at \(score.course)",
                type: .scorePosted,
                relatedId: score.id
            )
        }
    }
}

// League Invitations - Add to where you handle league member management
extension EnhancedLeagueService {
    func sendLeagueInviteNotifications(leagueId: String, leagueName: String, memberIds: [String]) {
        // Notify all newly added members
        for memberId in memberIds {
            NotificationManager.shared.createNotification(
                for: memberId,
                title: "League Invitation",
                message: "You've been invited to join \(leagueName)",
                type: .leagueInvite,
                relatedId: leagueId
            )
        }
    }
    
    func sendLeagueUpdateNotification(leagueId: String, leagueName: String, message: String) {
        // Get all league members
        let db = Firestore.firestore()
        
        db.collection("leagues").document(leagueId).getDocument { snapshot, error in
            guard let data = snapshot?.data(),
                  let hostId = data["hostUserId"] as? String,
                  let members = data["members"] as? [String] else {
                return
            }
            
            // Combine host and members
            var allMembers = members
            if !allMembers.contains(hostId) {
                allMembers.append(hostId)
            }
            
            // Notify all members
            for memberId in allMembers {
                NotificationManager.shared.createNotification(
                    for: memberId,
                    title: "\(leagueName) Update",
                    message: message,
                    type: .leagueUpdate,
                    relatedId: leagueId
                )
            }
        }
    }
    
    // Call this when a new round begins or scores are posted
    func sendRoundUpdateNotification(leagueId: String, leagueName: String, roundNumber: Int) {
        let db = Firestore.firestore()
        
        db.collection("leagues").document(leagueId).getDocument { snapshot, error in
            guard let data = snapshot?.data(),
                  let hostId = data["hostUserId"] as? String,
                  let members = data["members"] as? [String] else {
                return
            }
            
            // Combine host and members
            var allMembers = members
            if !allMembers.contains(hostId) {
                allMembers.append(hostId)
            }
            
            // Notify all members
            for memberId in allMembers {
                NotificationManager.shared.createNotification(
                    for: memberId,
                    title: "Round \(roundNumber) Started",
                    message: "A new round has started in \(leagueName)",
                    type: .leagueUpdate,
                    relatedId: leagueId
                )
            }
        }
    }
}