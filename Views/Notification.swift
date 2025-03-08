////
////  Notification.swift
////  Aldo
////
////  Created by Andrew Katsifis on 3/8/25.
////
//
//
//// NotificationModel.swift
//import Foundation
//import FirebaseFirestore
//
//struct Notification: Identifiable, Codable {
//    var id: String = UUID().uuidString
//    let userId: String
//    let title: String
//    let message: String
//    let type: NotificationType
//    let relatedId: String?
//    let timestamp: Date
//    var isRead: Bool
//    
//    enum NotificationType: String, Codable {
//        case friendRequest
//        case scorePosted
//        case leagueInvite
//        case leagueUpdate
//    }
//    
//    // Convert to Firestore data
//    func toDictionary() -> [String: Any] {
//        return [
//            "id": id,
//            "userId": userId,
//            "title": title,
//            "message": message,
//            "type": type.rawValue,
//            "relatedId": relatedId as Any,
//            "timestamp": Timestamp(date: timestamp),
//            "isRead": isRead
//        ]
//    }
//    
//    // Create from Firestore data
//    static func fromDictionary(_ data: [String: Any], id: String) -> Notification? {
//        guard 
//            let userId = data["userId"] as? String,
//            let title = data["title"] as? String,
//            let message = data["message"] as? String,
//            let typeString = data["type"] as? String,
//            let timestamp = data["timestamp"] as? Timestamp,
//            let isRead = data["isRead"] as? Bool,
//            let type = NotificationType(rawValue: typeString)
//        else {
//            return nil
//        }
//        
//        let relatedId = data["relatedId"] as? String
//        
//        return Notification(
//            id: id,
//            userId: userId,
//            title: title,
//            message: message,
//            type: type,
//            relatedId: relatedId,
//            timestamp: timestamp.dateValue(),
//            isRead: isRead
//        )
//    }
//}
//
//// NotificationManager.swift
//import Foundation
//import Firebase
//import FirebaseFirestore
//import SwiftUI
//import Combine
//
//class NotificationManager: ObservableObject {
//    static let shared = NotificationManager()
//    
//    @Published var notifications: [Notification] = []
//    @Published var unreadCount: Int = 0
//    
//    private var db = Firestore.firestore()
//    private var listenerRegistration: ListenerRegistration?
//    
//    init() {
//        // Start listening for auth state changes
//        Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
//            if let userId = user?.uid {
//                self?.startListeningForNotifications(userId: userId)
//            } else {
//                self?.stopListeningForNotifications()
//                self?.notifications = []
//                self?.unreadCount = 0
//            }
//        }
//    }
//    
//    deinit {
//        stopListeningForNotifications()
//    }
//    
//    // Start listening for notifications for a specific user
//    func startListeningForNotifications(userId: String) {
//        // Stop any existing listener first
//        stopListeningForNotifications()
//        
//        // Create a new listener
//        listenerRegistration = db.collection("users").document(userId)
//            .collection("notifications")
//            .order(by: "timestamp", descending: true)
//            .limit(to: 50)
//            .addSnapshotListener { [weak self] (snapshot, error) in
//                guard let self = self else { return }
//                
//                if let error = error {
//                    print("Error listening for notifications: \(error.localizedDescription)")
//                    return
//                }
//                
//                guard let documents = snapshot?.documents else { return }
//                
//                self.notifications = documents.compactMap { document in
//                    Notification.fromDictionary(document.data(), id: document.documentID)
//                }
//                
//                // Update unread count
//                self.unreadCount = self.notifications.filter { !$0.isRead }.count
//            }
//    }
//    
//    func stopListeningForNotifications() {
//        listenerRegistration?.remove()
//        listenerRegistration = nil
//    }
//    
//    // Create a notification
//    func createNotification(for userId: String, title: String, message: String, type: Notification.NotificationType, relatedId: String? = nil, completion: ((Error?) -> Void)? = nil) {
//        let notification = Notification(
//            userId: userId,
//            title: title,
//            message: message,
//            type: type,
//            relatedId: relatedId,
//            timestamp: Date(),
//            isRead: false
//        )
//        
//        db.collection("users").document(userId)
//            .collection("notifications").document(notification.id)
//            .setData(notification.toDictionary()) { error in
//                if let error = error {
//                    print("Error creating notification: \(error.localizedDescription)")
//                }
//                completion?(error)
//            }
//    }
//    
//    // Mark a notification as read
//    func markAsRead(notificationId: String, completion: ((Error?) -> Void)? = nil) {
//        guard let userId = Auth.auth().currentUser?.uid else {
//            completion?(NSError(domain: "NotificationManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
//            return
//        }
//        
//        db.collection("users").document(userId)
//            .collection("notifications").document(notificationId)
//            .updateData(["isRead": true]) { error in
//                if let error = error {
//                    print("Error marking notification as read: \(error.localizedDescription)")
//                }
//                
//                // Update local state
//                if let index = self.notifications.firstIndex(where: { $0.id == notificationId }) {
//                    DispatchQueue.main.async {
//                        self.notifications[index].isRead = true
//                        self.unreadCount = self.notifications.filter { !$0.isRead }.count
//                    }
//                }
//                
//                completion?(error)
//            }
//    }
//    
//    // Mark all notifications as read
//    func markAllAsRead(completion: ((Error?) -> Void)? = nil) {
//        guard let userId = Auth.auth().currentUser?.uid else {
//            completion?(NSError(domain: "NotificationManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
//            return
//        }
//        
//        // Get all unread notifications
//        let unreadIds = notifications.filter { !$0.isRead }.map { $0.id }
//        if unreadIds.isEmpty {
//            completion?(nil)
//            return
//        }
//        
//        let batch = db.batch()
//        
//        // Update each notification
//        for notificationId in unreadIds {
//            let notificationRef = db.collection("users").document(userId)
//                .collection("notifications").document(notificationId)
//            batch.updateData(["isRead": true], forDocument: notificationRef)
//        }
//        
//        // Commit the batch
//        batch.commit { error in
//            if let error = error {
//                print("Error marking all notifications as read: \(error.localizedDescription)")
//            } else {
//                // Update local state
//                DispatchQueue.main.async {
//                    for i in 0..<self.notifications.count {
//                        self.notifications[i].isRead = true
//                    }
//                    self.unreadCount = 0
//                }
//            }
//            
//            completion?(error)
//        }
//    }
//    
//    // Delete a notification
//    func deleteNotification(notificationId: String, completion: ((Error?) -> Void)? = nil) {
//        guard let userId = Auth.auth().currentUser?.uid else {
//            completion?(NSError(domain: "NotificationManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
//            return
//        }
//        
//        db.collection("users").document(userId)
//            .collection("notifications").document(notificationId)
//            .delete { error in
//                if let error = error {
//                    print("Error deleting notification: \(error.localizedDescription)")
//                }
//                
//                // Update local state (will happen automatically via listener)
//                completion?(error)
//            }
//    }
//}
//
//// NotificationView.swift
//import SwiftUI
//
//struct NotificationView: View {
//    @EnvironmentObject var notificationManager: NotificationManager
//    @State private var selectedNotification: Notification?
//    @Environment(\.presentationMode) var presentationMode
//    
//    var body: some View {
//        NavigationView {
//            List {
//                if notificationManager.notifications.isEmpty {
//                    VStack(spacing: 20) {
//                        Image(systemName: "bell.slash")
//                            .font(.system(size: 60))
//                            .foregroundColor(.gray)
//                            .padding(.top, 40)
//                        
//                        Text("No notifications")
//                            .font(.headline)
//                            .foregroundColor(.gray)
//                        
//                        Text("You're all caught up!")
//                            .font(.subheadline)
//                            .foregroundColor(.gray)
//                    }
//                    .frame(maxWidth: .infinity)
//                    .listRowBackground(Color.clear)
//                    .padding(.top, 60)
//                } else {
//                    ForEach(notificationManager.notifications) { notification in
//                        Button(action: {
//                            selectedNotification = notification
//                            
//                            // Mark as read when tapped
//                            if !notification.isRead {
//                                notificationManager.markAsRead(notificationId: notification.id)
//                            }
//                        }) {
//                            NotificationRow(notification: notification)
//                        }
//                    }
//                    .onDelete(perform: deleteNotifications)
//                }
//            }
//            .listStyle(InsetGroupedListStyle())
//            .navigationTitle("Notifications")
//            .navigationBarItems(
//                trailing: Group {
//                    if !notificationManager.notifications.isEmpty {
//                        Button("Mark All Read") {
//                            notificationManager.markAllAsRead()
//                        }
//                    }
//                }
//            )
//            .sheet(item: $selectedNotification) { notification in
//                NotificationDetailView(notification: notification)
//            }
//        }
//    }
//    
//    private func deleteNotifications(at offsets: IndexSet) {
//        for index in offsets {
//            let notification = notificationManager.notifications[index]
//            notificationManager.deleteNotification(notificationId: notification.id)
//        }
//    }
//}
//
//struct NotificationRow: View {
//    let notification: Notification
//    
//    var body: some View {
//        HStack(alignment: .top, spacing: 15) {
//            // Icon based on notification type
//            ZStack {
//                Circle()
//                    .fill(iconBackgroundColor)
//                    .frame(width: 40, height: 40)
//                
//                Image(systemName: iconName)
//                    .foregroundColor(.white)
//            }
//            
//            VStack(alignment: .leading, spacing: 5) {
//                Text(notification.title)
//                    .font(.headline)
//                    .foregroundColor(notification.isRead ? .primary : .blue)
//                
//                Text(notification.message)
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//                    .lineLimit(2)
//                
//                Text(timeAgo(from: notification.timestamp))
//                    .font(.caption)
//                    .foregroundColor(.gray)
//            }
//            
//            Spacer()
//            
//            if !notification.isRead {
//                Circle()
//                    .fill(Color.blue)
//                    .frame(width: 10, height: 10)
//            }
//        }
//        .padding(.vertical, 8)
//        .contentShape(Rectangle())
//    }
//    
//    // Icon based on notification type
//    private var iconName: String {
//        switch notification.type {
//        case .friendRequest:
//            return "person.badge.plus"
//        case .scorePosted:
//            return "flag.fill"
//        case .leagueInvite:
//            return "person.3.fill"
//        case .leagueUpdate:
//            return "calendar.badge.clock"
//        }
//    }
//    
//    // Background color based on notification type
//    private var iconBackgroundColor: Color {
//        switch notification.type {
//        case .friendRequest:
//            return .blue
//        case .scorePosted:
//            return .green
//        case .leagueInvite:
//            return .purple
//        case .leagueUpdate:
//            return .orange
//        }
//    }
//    
//    // Format timestamp as time ago
//    private func timeAgo(from date: Date) -> String {
//        let formatter = RelativeDateTimeFormatter()
//        formatter.unitsStyle = .abbreviated
//        return formatter.localizedString(for: date, relativeTo: Date())
//    }
//}
//
//struct NotificationDetailView: View {
//    let notification: Notification
//    @Environment(\.presentationMode) var presentationMode
//    @EnvironmentObject var notificationManager: NotificationManager
//    
//    var body: some View {
//        NavigationView {
//            VStack(alignment: .leading, spacing: 20) {
//                // Icon and title
//                HStack {
//                    ZStack {
//                        Circle()
//                            .fill(iconBackgroundColor)
//                            .frame(width: 50, height: 50)
//                        
//                        Image(systemName: iconName)
//                            .foregroundColor(.white)
//                            .font(.system(size: 24))
//                    }
//                    
//                    VStack(alignment: .leading) {
//                        Text(notification.title)
//                            .font(.title2)
//                            .fontWeight(.bold)
//                        
//                        Text(formattedDate(notification.timestamp))
//                            .font(.subheadline)
//                            .foregroundColor(.gray)
//                    }
//                    .padding(.leading, 10)
//                }
//                .padding()
//                
//                // Message
//                Text(notification.message)
//                    .font(.body)
//                    .padding()
//                
//                // Action button based on notification type
//                actionButton
//                
//                Spacer()
//            }
//            .padding()
//            .navigationBarItems(trailing: Button("Done") {
//                presentationMode.wrappedValue.dismiss()
//            })
//        }
//    }
//    
//    @ViewBuilder
//    private var actionButton: some View {
//        switch notification.type {
//        case .friendRequest:
//            if let userId = notification.relatedId {
//                Button(action: {
//                    // Accept friend request
//                    acceptFriendRequest(userId: userId)
//                    presentationMode.wrappedValue.dismiss()
//                }) {
//                    Text("Accept Friend Request")
//                        .foregroundColor(.white)
//                        .padding()
//                        .frame(maxWidth: .infinity)
//                        .background(Color.blue)
//                        .cornerRadius(10)
//                }
//            } else {
//                EmptyView()
//            }
//            
//        case .scorePosted:
//            if let scoreId = notification.relatedId {
//                Button(action: {
//                    // View score detail
//                    presentationMode.wrappedValue.dismiss()
//                }) {
//                    Text("View Score")
//                        .foregroundColor(.white)
//                        .padding()
//                        .frame(maxWidth: .infinity)
//                        .background(Color.green)
//                        .cornerRadius(10)
//                }
//            } else {
//                EmptyView()
//            }
//            
//        case .leagueInvite:
//            if let leagueId = notification.relatedId {
//                Button(action: {
//                    // Join league
//                    presentationMode.wrappedValue.dismiss()
//                }) {
//                    Text("View League")
//                        .foregroundColor(.white)
//                        .padding()
//                        .frame(maxWidth: .infinity)
//                        .background(Color.purple)
//                        .cornerRadius(10)
//                }
//            } else {
//                EmptyView()
//            }
//            
//        case .leagueUpdate:
//            Button(action: {
//                // View league
//                presentationMode.wrappedValue.dismiss()
//            }) {
//                Text("View Update")
//                    .foregroundColor(.white)
//                    .padding()
//                    .frame(maxWidth: .infinity)
//                    .background(Color.orange)
//                    .cornerRadius(10)
//            }
//        }
//    }
//    
//    // Icon based on notification type
//    private var iconName: String {
//        switch notification.type {
//        case .friendRequest:
//            return "person.badge.plus"
//        case .scorePosted:
//            return "flag.fill"
//        case .leagueInvite:
//            return "person.3.fill"
//        case .leagueUpdate:
//            return "calendar.badge.clock"
//        }
//    }
//    
//    // Background color based on notification type
//    private var iconBackgroundColor: Color {
//        switch notification.type {
//        case .friendRequest:
//            return .blue
//        case .scorePosted:
//            return .green
//        case .leagueInvite:
//            return .purple
//        case .leagueUpdate:
//            return .orange
//        }
//    }
//    
//    // Format date
//    private func formattedDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//    
//    // Accept friend request
//    private func acceptFriendRequest(userId: String) {
//        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
//        
//        let db = Firestore.firestore()
//        let batch = db.batch()
//        
//        // Add each user to the other's friends list
//        let currentUserRef = db.collection("users").document(currentUserId)
//        let otherUserRef = db.collection("users").document(userId)
//        
//        batch.updateData([
//            "friends": FieldValue.arrayUnion([userId])
//        ], forDocument: currentUserRef)
//        
//        batch.updateData([
//            "friends": FieldValue.arrayUnion([currentUserId])
//        ], forDocument: otherUserRef)
//        
//        // Commit the batch
//        batch.commit { error in
//            if let error = error {
//                print("Error accepting friend request: \(error.localizedDescription)")
//            } else {
//                // Create a notification for the other user
//                NotificationManager.shared.createNotification(
//                    for: userId,
//                    title: "Friend Request Accepted",
//                    message: "Your friend request was accepted!",
//                    type: .friendRequest,
//                    relatedId: currentUserId
//                )
//            }
//        }
//    }
//}
//
//// NotificationBadge.swift
//import SwiftUI
//
//struct NotificationBadge: View {
//    let count: Int
//    
//    var body: some View {
//        ZStack(alignment: .topTrailing) {
//            Color.clear
//            
//            if count > 0 {
//                Text(count > 99 ? "99+" : "\(count)")
//                    .font(.system(size: 12))
//                    .foregroundColor(.white)
//                    .padding(4)
//                    .background(Color.red)
//                    .clipShape(Capsule())
//                    // Adjust position as needed for your UI
//                    .offset(x: 12, y: -12)
//                    .animation(.default)
//            }
//        }
//    }
//}
//
//// Notification integration with MainView
//// Add the following to MainView.swift:
//
///*
//@EnvironmentObject var notificationManager: NotificationManager
//@State private var showingNotifications = false
//
//// In the TabView, add a notification button in the toolbar
//.toolbar {
//    ToolbarItem(placement: .navigationBarTrailing) {
//        Button(action: {
//            showingNotifications = true
//        }) {
//            ZStack {
//                Image(systemName: "bell.fill")
//                    .foregroundColor(.blue)
//                
//                NotificationBadge(count: notificationManager.unreadCount)
//            }
//        }
//    }
//}
//.sheet(isPresented: $showingNotifications) {
//    NotificationView()
//}
//*/
//
//// Example code to trigger notifications:
//
//// Friend request notification
//func sendFriendRequestNotification(to userId: String, from userName: String) {
//    NotificationManager.shared.createNotification(
//        for: userId,
//        title: "New Friend Request",
//        message: "\(userName) sent you a friend request",
//        type: .friendRequest,
//        relatedId: Auth.auth().currentUser?.uid
//    )
//}
//
//// Score posted notification
//func sendScoreNotification(to userIds: [String], from userName: String, score: Int, courseName: String, scoreId: String) {
//    for userId in userIds {
//        NotificationManager.shared.createNotification(
//            for: userId,
//            title: "New Score Posted",
//            message: "\(userName) scored \(score) at \(courseName)",
//            type: .scorePosted,
//            relatedId: scoreId
//        )
//    }
//}
//
//// League invitation notification
//func sendLeagueInviteNotification(to userId: String, leagueName: String, leagueId: String) {
//    NotificationManager.shared.createNotification(
//        for: userId,
//        title: "League Invitation",
//        message: "You've been invited to join the \(leagueName) league",
//        type: .leagueInvite,
//        relatedId: leagueId
//    )
//}
//
//// League update notification
//func sendLeagueUpdateNotification(to userIds: [String], leagueName: String, message: String, leagueId: String) {
//    for userId in userIds {
//        NotificationManager.shared.createNotification(
//            for: userId,
//            title: "\(leagueName) Update",
//            message: message,
//            type: .leagueUpdate,
//            relatedId: leagueId
//        )
//    }
//}
