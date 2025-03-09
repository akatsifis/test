import Foundation
import UserNotifications
import SwiftUI

enum NotificationType: String, Codable {
    case friendRequest
    case leagueInvite
    case gameReminder
    case scoreUpdate
    case general
}

struct AldoNotification: Identifiable, Codable {
    var id: String = UUID().uuidString
    var title: String
    var body: String
    var date: Date
    var type: NotificationType
    var read: Bool = false
}

class AldoNotificationManager: ObservableObject {
    static let shared = AldoNotificationManager()
    
    // System notification properties
    @Published var hasPermission = false
    @Published var pendingNotifications: [UNNotificationRequest] = []
    
    // In-app notification properties
    @Published var notifications: [AldoNotification] = []
    
    init() {
        checkPermission()
        loadPendingNotifications()
        loadSavedNotifications()
    }
    
    // MARK: - System Notification Methods
    
    func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.hasPermission = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            DispatchQueue.main.async {
                self.hasPermission = success
                if let error = error {
                    print("Notification permission error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func scheduleNotification(title: String, body: String, date: Date) {
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Create trigger
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // Create request
        let identifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Add request to notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    self.loadPendingNotifications()
                }
            }
        }
    }
    
    func loadPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                self.pendingNotifications = requests
            }
        }
    }
    
    func cancelNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        loadPendingNotifications()
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        loadPendingNotifications()
    }
    
    // MARK: - In-App Notification Methods
    
    func addNotification(title: String, body: String, type: NotificationType) {
        let notification = AldoNotification(
            title: title,
            body: body,
            date: Date(),
            type: type
        )
        
        DispatchQueue.main.async {
            self.notifications.append(notification)
            self.saveNotifications()
        }
    }
    
    func markAsRead(at index: Int) {
        guard index >= 0 && index < notifications.count else { return }
        
        DispatchQueue.main.async {
            self.notifications[index].read = true
            self.saveNotifications()
        }
    }
    
    func markAllAsRead() {
        DispatchQueue.main.async {
            for i in 0..<self.notifications.count {
                self.notifications[i].read = true
            }
            self.saveNotifications()
        }
    }
    
    func deleteNotification(at index: Int) {
        guard index >= 0 && index < notifications.count else { return }
        
        DispatchQueue.main.async {
            self.notifications.remove(at: index)
            self.saveNotifications()
        }
    }
    
    // MARK: - Storage Methods
    
    private func saveNotifications() {
        if let encoded = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(encoded, forKey: "savedNotifications")
        }
    }
    
    private func loadSavedNotifications() {
        if let savedNotifications = UserDefaults.standard.data(forKey: "savedNotifications") {
            if let decodedNotifications = try? JSONDecoder().decode([AldoNotification].self, from: savedNotifications) {
                notifications = decodedNotifications
            }
        }
    }
    
    // MARK: - Combined Methods (both system and in-app)
    
    func scheduleAndAddNotification(title: String, body: String, date: Date, type: NotificationType) {
        // Schedule system notification
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let identifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    self.loadPendingNotifications()
                }
            }
        }
        
        // Add in-app notification
        let notification = AldoNotification(
            id: identifier,
            title: title,
            body: body,
            date: date,
            type: type
        )
        
        DispatchQueue.main.async {
            self.notifications.append(notification)
            self.saveNotifications()
        }
    }
}
