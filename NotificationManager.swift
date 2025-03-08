////
////  NotificationManager.swift
////  Aldo
////
////  Created by Andrew Katsifis on 3/8/25.
////
//
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
