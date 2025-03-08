//
//  LeagueRound.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/8/25.
//


import Foundation
import FirebaseFirestore

struct LeagueRound: Identifiable {
    let id: String
    let number: Int
    let score: Int
    let createdAt: Timestamp
}