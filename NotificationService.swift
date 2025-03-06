//
//  NotificationService.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/5/25.
//


import Firebase

class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func sendPushNotification(to user: Models.User) {
        // This will send a push notification to a specific user based on their FCM token
        guard let fcmToken = user.fcmToken else {
            print("No FCM token available for user")
            return
        }

        let message = [
            "to": fcmToken,
            "notification": [
                "title": "You've been added to the league!",
                "body": "Join the game and track your progress."
            ],
            "priority": "high"
        ] as [String : Any]

        // Send the request to Firebase Cloud Messaging
        sendFCMRequest(message)
    }

    private func sendFCMRequest(_ message: [String: Any]) {
        let url = URL(string: "https://fcm.googleapis.com/fcm/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("key=YOUR_FCM_SERVER_KEY", forHTTPHeaderField: "Authorization") // Replace with your server key
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            request.httpBody = jsonData
        } catch {
            print("Failed to serialize FCM message: \(error.localizedDescription)")
            return
        }

        // Perform the network request to send the notification
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending push notification: \(error.localizedDescription)")
                return
            }

            if let response = response as? HTTPURLResponse, response.statusCode == 200 {
                print("Push notification sent successfully")
            } else {
                print("Failed to send push notification")
            }
        }

        task.resume()
    }
}
