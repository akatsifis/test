// UserModel.swift
// Aldo
//
// Created by Andrew Katsifis on 6/12/24.

import Foundation
import FirebaseFirestore

struct Models {
    struct User: Identifiable, Codable {
        let id: String
        var username: String
        var firstName: String
        var lastName: String
        var email: String
        var phoneNumber: String
        var bio: String = ""
        var location: String = ""
        var friends: [String]
        var scores: [Score]
        var steps: Int
        var profilePicture: String?
        var notificationsEnabled: Bool = true
        var selectedLanguage: String = "English"
        var fcmToken: String?

        struct Score: Codable, Identifiable {
            var id: String
            let course: String
            let score: Int
            let date: Date
            let holesPlayed: String
            var steps: Int?
            var distance: Double?
            var caloriesBurned: Double?
        }
        
        // Convert to dictionary for Firebase
        func toDictionary() -> [String: Any] {
            return [
                "username": username,
                "firstName": firstName,
                "lastName": lastName,
                "email": email,
                "phoneNumber": phoneNumber,
                "bio": bio,
                "location": location,
                "profilePicture": profilePicture ?? "",
                "fcmToken": fcmToken ?? "",
                "friends": friends,
                "scores": scores.map { score in
                    return [
                        "id": score.id,
                        "course": score.course,
                        "score": score.score,
                        "date": score.date,
                        "holesPlayed": score.holesPlayed,
                        "steps": score.steps ?? 0,
                        "distance": score.distance ?? 0.0,
                        "caloriesBurned": score.caloriesBurned ?? 0.0
                    ]
                },
                "steps": steps,
                "notificationsEnabled": notificationsEnabled,
                "selectedLanguage": selectedLanguage
            ]
        }
        
        // Parse from dictionary from Firebase
        static func fromDictionary(_ dict: [String: Any], id: String) -> User? {
            guard
                let username = dict["username"] as? String,
                let email = dict["email"] as? String
            else {
                return nil
            }
            
            let firstName = dict["firstName"] as? String ?? ""
            let lastName = dict["lastName"] as? String ?? ""
            let phoneNumber = dict["phoneNumber"] as? String ?? ""
            let bio = dict["bio"] as? String ?? ""
            let location = dict["location"] as? String ?? ""
            let profilePicture = dict["profilePicture"] as? String
            let fcmToken = dict["fcmToken"] as? String
            let friends = dict["friends"] as? [String] ?? []
            let notificationsEnabled = dict["notificationsEnabled"] as? Bool ?? true
            let selectedLanguage = dict["selectedLanguage"] as? String ?? "English"
            
            var scores: [Score] = []
            if let scoresArray = dict["scores"] as? [[String: Any]] {
                scores = scoresArray.compactMap { scoreDict in
                    guard
                        let scoreId = scoreDict["id"] as? String,
                        let course = scoreDict["course"] as? String,
                        let score = scoreDict["score"] as? Int
                    else {
                        return nil
                    }
                    
                    let date = (scoreDict["date"] as? Timestamp)?.dateValue() ?? Date()
                    let holesPlayed = scoreDict["holesPlayed"] as? String ?? "18 Holes"
                    let steps = scoreDict["steps"] as? Int
                    let distance = scoreDict["distance"] as? Double
                    let caloriesBurned = scoreDict["caloriesBurned"] as? Double
                    
                    return Score(id: scoreId,
                                course: course,
                                score: score,
                                date: date,
                                holesPlayed: holesPlayed,
                                steps: steps,
                                distance: distance,
                                caloriesBurned: caloriesBurned)
                }
            }
            
            let steps = dict["steps"] as? Int ?? 0
            
            return User(
                id: id,
                username: username,
                firstName: firstName,
                lastName: lastName,
                email: email,
                phoneNumber: phoneNumber,
                bio: bio,
                location: location,
                friends: friends,
                scores: scores,
                steps: steps,
                profilePicture: profilePicture,
                notificationsEnabled: notificationsEnabled,
                selectedLanguage: selectedLanguage,
                fcmToken: fcmToken
            )
        }
    }
}
