////
////  NotificationModel.swift
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
