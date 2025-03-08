//
//  AldoNotificationView.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/8/25.
//


// AldoNotificationView.swift
import SwiftUI
import Firebase
import FirebaseFirestore

struct AldoNotificationView: View {
    @EnvironmentObject var notificationManager: AldoNotificationManager
    @State private var selectedNotification: AldoNotification?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                if notificationManager.notifications.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                            .padding(.top, 40)
                        
                        Text("No notifications")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("You're all caught up!")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .padding(.top, 60)
                } else {
                    ForEach(notificationManager.notifications) { notification in
                        Button(action: {
                            selectedNotification = notification
                            
                            // Mark as read when tapped
                            if !notification.isRead {
                                notificationManager.markAsRead(notificationId: notification.id)
                            }
                        }) {
                            NotificationRow(notification: notification)
                        }
                    }
                    .onDelete(perform: deleteNotifications)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Notifications")
            .navigationBarItems(
                trailing: Group {
                    if !notificationManager.notifications.isEmpty {
                        Button("Mark All Read") {
                            notificationManager.markAllAsRead()
                        }
                    }
                }
            )
            .sheet(item: $selectedNotification) { notification in
                NotificationDetailView(notification: notification)
            }
        }
    }
    
    private func deleteNotifications(at offsets: IndexSet) {
        for index in offsets {
            let notification = notificationManager.notifications[index]
            notificationManager.deleteNotification(notificationId: notification.id)
        }
    }
}

struct NotificationRow: View {
    let notification: AldoNotification
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // Icon based on notification type
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconName)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundColor(notification.isRead ? .primary : .blue)
                
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(timeAgo(from: notification.timestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if !notification.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    // Icon based on notification type
    private var iconName: String {
        switch notification.type {
        case .friendRequest:
            return "person.badge.plus"
        case .scorePosted:
            return "flag.fill"
        case .leagueInvite:
            return "person.3.fill"
        case .leagueUpdate:
            return "calendar.badge.clock"
        }
    }
    
    // Background color based on notification type
    private var iconBackgroundColor: Color {
        switch notification.type {
        case .friendRequest:
            return .blue
        case .scorePosted:
            return .green
        case .leagueInvite:
            return .purple
        case .leagueUpdate:
            return .orange
        }
    }
    
    // Format timestamp as time ago
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct NotificationDetailView: View {
    let notification: AldoNotification
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var notificationManager: AldoNotificationManager
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Icon and title
                HStack {
                    ZStack {
                        Circle()
                            .fill(iconBackgroundColor)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: iconName)
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                    }
                    
                    VStack(alignment: .leading) {
                        Text(notification.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(formattedDate(notification.timestamp))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.leading, 10)
                }
                .padding()
                
                // Message
                Text(notification.message)
                    .font(.body)
                    .padding()
                
                // Action button based on notification type
                actionButton
                
                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        switch notification.type {
        case .friendRequest:
            if let userId = notification.relatedId {
                Button(action: {
                    // Accept friend request
                    acceptFriendRequest(userId: userId)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Accept Friend Request")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            } else {
                EmptyView()
            }
            
        case .scorePosted:
            if let scoreId = notification.relatedId {
                Button(action: {
                    // View score detail
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("View Score")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(10)
                }
            } else {
                EmptyView()
            }
            
        case .leagueInvite:
            if let leagueId = notification.relatedId {
                Button(action: {
                    // Join league
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("View League")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .cornerRadius(10)
                }
            } else {
                EmptyView()
            }
            
        case .leagueUpdate:
            Button(action: {
                // View league
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("View Update")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .cornerRadius(10)
            }
        }
    }
    
    // Icon based on notification type
    private var iconName: String {
        switch notification.type {
        case .friendRequest:
            return "person.badge.plus"
        case .scorePosted:
            return "flag.fill"
        case .leagueInvite:
            return "person.3.fill"
        case .leagueUpdate:
            return "calendar.badge.clock"
        }
    }
    
    // Background color based on notification type
    private var iconBackgroundColor: Color {
        switch notification.type {
        case .friendRequest:
            return .blue
        case .scorePosted:
            return .green
        case .leagueInvite:
            return .purple
        case .leagueUpdate:
            return .orange
        }
    }
    
    // Format date
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Accept friend request
    private func acceptFriendRequest(userId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        let batch = db.batch()
        
        // Add each user to the other's friends list
        let currentUserRef = db.collection("users").document(currentUserId)
        let otherUserRef = db.collection("users").document(userId)
        
        batch.updateData([
            "friends": FieldValue.arrayUnion([userId])
        ], forDocument: currentUserRef)
        
        batch.updateData([
            "friends": FieldValue.arrayUnion([currentUserId])
        ], forDocument: otherUserRef)
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                print("Error accepting friend request: \(error.localizedDescription)")
            } else {
                // Create a notification for the other user
                AldoNotificationManager.shared.createNotification(
                    for: userId,
                    title: "Friend Request Accepted",
                    message: "Your friend request was accepted!",
                    type: .friendRequest,
                    relatedId: currentUserId
                )
            }
        }
    }
}