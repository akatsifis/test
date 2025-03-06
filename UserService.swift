//
//  UserService.swift
//  Aldo
//
//  Created by Andrew Katsifis on 6/12/24.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseStorage
import UIKit
import Combine

class UserService: ObservableObject {
    static let shared = UserService()
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    @Published var currentUser: Models.User?
    @Published var isLoading = false
    
    // MARK: - FCM Token Management
    
    func saveFCMToken(_ token: String, completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(uid).updateData([
            "fcmToken": token
        ]) { error in
            if let error = error {
                print("Error saving FCM token: \(error.localizedDescription)")
                completion(false)
            } else {
                print("FCM token saved successfully")
                completion(true)
            }
        }
    }
    
    // MARK: - User Creation
    
    func createUser(email: String,
                   username: String,
                   firstName: String,
                   lastName: String,
                   phoneNumber: String,
                   bio: String,
                   location: String,
                   profileImage: UIImage?,
                   completion: @escaping (Result<Models.User, Error>) -> Void) {
        
        isLoading = true
        
        // First, upload profile image if it exists
        uploadProfileImage(image: profileImage) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let imageURL):
                // Create user model with minimal required fields
                let newUser = Models.User(
                    id: "",
                    username: username,
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    phoneNumber: phoneNumber,
                    bio: bio,
                    location: location,
                    friends: [],
                    scores: [],
                    steps: 0,
                    profilePicture: imageURL
                )
                
                // Save to Firestore
                if let uid = Auth.auth().currentUser?.uid {
                    self.db.collection("users").document(uid).setData(newUser.toDictionary()) { error in
                        self.isLoading = false
                        
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            var savedUser = newUser
                            // Update the ID field with the Firestore document ID
                            savedUser = Models.User(
                                id: uid,
                                username: newUser.username,
                                firstName: newUser.firstName,
                                lastName: newUser.lastName,
                                email: newUser.email,
                                phoneNumber: newUser.phoneNumber,
                                bio: newUser.bio,
                                location: newUser.location,
                                friends: newUser.friends,
                                scores: newUser.scores,
                                steps: newUser.steps,
                                profilePicture: newUser.profilePicture,
                                notificationsEnabled: newUser.notificationsEnabled,
                                selectedLanguage: newUser.selectedLanguage
                            )
                            self.currentUser = savedUser
                            completion(.success(savedUser))
                        }
                    }
                } else {
                    self.isLoading = false
                    completion(.failure(NSError(domain: "UserService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
                }
                
            case .failure(let error):
                self.isLoading = false
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Profile Image Handling
    
    func uploadProfileImage(image: UIImage?, completion: @escaping (Result<String?, Error>) -> Void) {
        guard let image = image else {
            // No image to upload
            completion(.success(nil))
            return
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.75) else {
            completion(.failure(NSError(domain: "UserService", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])))
            return
        }
        
        // Create a unique filename
        let imageName = UUID().uuidString + ".jpg"
        let storageRef = storage.reference().child("profile_images/\(imageName)")
        
        // Upload the image
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Get download URL
            storageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                if let url = url {
                    completion(.success(url.absoluteString))
                } else {
                    completion(.failure(NSError(domain: "UserService", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                }
            }
        }
    }
    
    // MARK: - User Data Management
    
    func fetchCurrentUser(completion: @escaping (Result<Models.User, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "UserService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        
        isLoading = true
        
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists, let data = snapshot.data() else {
                completion(.failure(NSError(domain: "UserService", code: 1004, userInfo: [NSLocalizedDescriptionKey: "User data not found"])))
                return
            }
            
            if let user = Models.User.fromDictionary(data, id: uid) {
                self.currentUser = user
                completion(.success(user))
            } else {
                completion(.failure(NSError(domain: "UserService", code: 1005, userInfo: [NSLocalizedDescriptionKey: "Failed to parse user data"])))
            }
        }
    }
    
    func updateUser(userData: Models.User, completion: @escaping (Result<Models.User, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "UserService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        
        isLoading = true
        
        db.collection("users").document(uid).updateData(userData.toDictionary()) { [weak self] error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                completion(.failure(error))
            } else {
                self.currentUser = userData
                completion(.success(userData))
            }
        }
    }
    
    func updateProfilePicture(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "UserService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        
        isLoading = true
        
        uploadProfileImage(image: image) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let imageURL):
                guard let imageURL = imageURL else {
                    self.isLoading = false
                    completion(.failure(NSError(domain: "UserService", code: 1006, userInfo: [NSLocalizedDescriptionKey: "No image URL returned"])))
                    return
                }
                
                // Update just the profile picture URL
                self.db.collection("users").document(uid).updateData(["profilePicture": imageURL]) { error in
                    self.isLoading = false
                    
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        // Update the current user
                        if var user = self.currentUser {
                            // Create a new user with the updated profile picture
                            let updatedUser = Models.User(
                                id: user.id,
                                username: user.username,
                                firstName: user.firstName,
                                lastName: user.lastName,
                                email: user.email,
                                phoneNumber: user.phoneNumber,
                                bio: user.bio,
                                location: user.location,
                                friends: user.friends,
                                scores: user.scores,
                                steps: user.steps,
                                profilePicture: imageURL,
                                notificationsEnabled: user.notificationsEnabled,
                                selectedLanguage: user.selectedLanguage
                            )
                            self.currentUser = updatedUser
                        }
                        
                        completion(.success(imageURL))
                    }
                }
                
            case .failure(let error):
                self.isLoading = false
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - User Search
    
    func searchUsers(query: String, completion: @escaping (Result<[Models.User], Error>) -> Void) {
        isLoading = true
        
        // Create queries for username, firstName, lastName and phoneNumber
        let usernameQuery = db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: query)
            .whereField("username", isLessThanOrEqualTo: query + "\u{f8ff}")
            .limit(to: 20)
            
        let phoneQuery = db.collection("users")
            .whereField("phoneNumber", isGreaterThanOrEqualTo: query)
            .whereField("phoneNumber", isLessThanOrEqualTo: query + "\u{f8ff}")
            .limit(to: 20)
            
        let nameQuery = db.collection("users")
            .whereField("firstName", isGreaterThanOrEqualTo: query)
            .whereField("firstName", isLessThanOrEqualTo: query + "\u{f8ff}")
            .limit(to: 20)
            
        let lastNameQuery = db.collection("users")
            .whereField("lastName", isGreaterThanOrEqualTo: query)
            .whereField("lastName", isLessThanOrEqualTo: query + "\u{f8ff}")
            .limit(to: 20)
        
        // Execute all queries
        var users: [Models.User] = []
        var errors: [Error] = []
        let group = DispatchGroup()
        
        // Username query
        group.enter()
        usernameQuery.getDocuments { snapshot, error in
            defer { group.leave() }
            
            if let error = error {
                errors.append(error)
                return
            }
            
            if let documents = snapshot?.documents {
                for doc in documents {
                    if let user = Models.User.fromDictionary(doc.data(), id: doc.documentID) {
                        users.append(user)
                    }
                }
            }
        }
        
        // Phone query
        group.enter()
        phoneQuery.getDocuments { snapshot, error in
            defer { group.leave() }
            
            if let error = error {
                errors.append(error)
                return
            }
            
            if let documents = snapshot?.documents {
                for doc in documents {
                    if let user = Models.User.fromDictionary(doc.data(), id: doc.documentID) {
                        // Avoid duplicates
                        if !users.contains(where: { $0.id == user.id }) {
                            users.append(user)
                        }
                    }
                }
            }
        }
        
        // First name query
        group.enter()
        nameQuery.getDocuments { snapshot, error in
            defer { group.leave() }
            
            if let error = error {
                errors.append(error)
                return
            }
            
            if let documents = snapshot?.documents {
                for doc in documents {
                    if let user = Models.User.fromDictionary(doc.data(), id: doc.documentID) {
                        // Avoid duplicates
                        if !users.contains(where: { $0.id == user.id }) {
                            users.append(user)
                        }
                    }
                }
            }
        }
        
        // Last name query
        group.enter()
        lastNameQuery.getDocuments { snapshot, error in
            defer { group.leave() }
            
            if let error = error {
                errors.append(error)
                return
            }
            
            if let documents = snapshot?.documents {
                for doc in documents {
                    if let user = Models.User.fromDictionary(doc.data(), id: doc.documentID) {
                        // Avoid duplicates
                        if !users.contains(where: { $0.id == user.id }) {
                            users.append(user)
                        }
                    }
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
            
            if !errors.isEmpty, users.isEmpty {
                // Only return error if we have no users and at least one error
                completion(.failure(errors.first!))
            } else {
                completion(.success(users))
            }
        }
    }
    
    // MARK: - Add Score
    
    func addScore(score: Models.User.Score, completion: @escaping (Result<Models.User, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "UserService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        
        isLoading = true
        
        // Fetch current user data first
        fetchCurrentUser { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(var user):
                // Create a new user with updated scores
                var scores = user.scores
                scores.append(score)
                
                let updatedUser = Models.User(
                    id: user.id,
                    username: user.username,
                    firstName: user.firstName,
                    lastName: user.lastName,
                    email: user.email,
                    phoneNumber: user.phoneNumber,
                    bio: user.bio,
                    location: user.location,
                    friends: user.friends,
                    scores: scores,
                    steps: user.steps,
                    profilePicture: user.profilePicture,
                    notificationsEnabled: user.notificationsEnabled,
                    selectedLanguage: user.selectedLanguage
                )
                
                // Update the user document with the new scores array
                self.db.collection("users").document(uid).updateData([
                    "scores": updatedUser.scores.map { score in
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
                    }
                ]) { error in
                    self.isLoading = false
                    
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        self.currentUser = updatedUser
                        completion(.success(updatedUser))
                    }
                }
                
            case .failure(let error):
                self.isLoading = false
                completion(.failure(error))
            }
        }
    }
}
