//
//  User.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/5/25.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct User: Identifiable, Codable {
    let id: String
    var username: String
    var firstName: String
    var lastName: String
    var email: String
    var phoneNumber: String
    var friends: [String]
    var scores: [Score]
    var steps: Int
    var profilePicture: String?

    struct Score: Codable, Identifiable {
        var id: UUID = UUID()
        let course: String
        let score: Int
    }
}

struct Friend: Identifiable, Codable {
    @DocumentID var id: String?
    var username: String
    var profileImageURL: URL?
    var rounds: [GolfRound]
}

struct GolfRound: Identifiable, Codable {
    @DocumentID var id: String?
    var course: String
    var scores: [Int]
    var steps: Int
    var distance: Double
    var caloriesBurned: Double
    var date: Date
}
