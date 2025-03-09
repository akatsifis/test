import SwiftUI

struct AldoNotificationView: View {
    @ObservedObject var notificationManager = AldoNotificationManager.shared
    
    var body: some View {
        NavigationView {
            VStack {
                if notificationManager.notifications.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Notifications")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("When you receive notifications, they will appear here.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(notificationManager.notifications.indices, id: \.self) { index in
                            NotificationRow(notification: notificationManager.notifications[index])
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    notificationManager.markAsRead(at: index)
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        notificationManager.deleteNotification(at: index)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarItems(
                trailing: Button(action: {
                    notificationManager.markAllAsRead()
                }) {
                    Text("Mark All Read")
                }
                .disabled(notificationManager.notifications.isEmpty)
            )
        }
    }
}

struct NotificationRow: View {
    let notification: AldoNotification
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon based on notification type
            Image(systemName: iconForType(notification.type))
                .font(.system(size: 24))
                .foregroundColor(colorForType(notification.type))
                .frame(width: 40, height: 40)
                .background(colorForType(notification.type).opacity(0.2))
                .cornerRadius(20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundColor(notification.read ? .gray : .primary)
                
                Text(notification.body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(timeAgoString(from: notification.date))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if !notification.read {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func iconForType(_ type: NotificationType) -> String {
        switch type {
        case .friendRequest:
            return "person.badge.plus"
        case .leagueInvite:
            return "person.3"
        case .gameReminder:
            return "calendar"
        case .scoreUpdate:
            return "chart.bar"
        case .general:
            return "bell"
        }
    }
    
    private func colorForType(_ type: NotificationType) -> Color {
        switch type {
        case .friendRequest:
            return .blue
        case .leagueInvite:
            return .green
        case .gameReminder:
            return .orange
        case .scoreUpdate:
            return .purple
        case .general:
            return .gray
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            return day == 1 ? "Yesterday" : "\(day) days ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour) hour\(hour == 1 ? "" : "s") ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute) minute\(minute == 1 ? "" : "s") ago"
        } else {
            return "Just now"
        }
    }
}
