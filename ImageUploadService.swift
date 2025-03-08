//
//  ImageUploadService.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/5/25.
//
import UIKit
import Firebase
import FirebaseStorage

class ImageUploadService {
    static let shared = ImageUploadService()
    private let storage = Storage.storage()
    private let maxRetries = 3
    private let defaultCompressionQuality: CGFloat = 0.7
    
    enum ImageUploadError: Error {
        case imageConversionFailed
        case uploadFailed
        case downloadURLFailed
        case userNotAuthenticated
        
        var description: String {
            switch self {
            case .imageConversionFailed:
                return "Failed to convert image to data"
            case .uploadFailed:
                return "Failed to upload image"
            case .downloadURLFailed:
                return "Failed to get download URL"
            case .userNotAuthenticated:
                return "User not authenticated"
            }
        }
    }
    
    // Upload image with default settings
    func uploadImage(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        uploadImage(image: image, path: "profile_images", compressionQuality: defaultCompressionQuality, completion: completion)
    }
    
    // Upload image with custom path and compression
    func uploadImage(image: UIImage, path: String, compressionQuality: CGFloat = 0.7, completion: @escaping (Result<String, Error>) -> Void) {
        print("DEBUG: uploadImage called")
        print("DEBUG: Image size: \(image.size)")
        print("DEBUG: Compression quality: \(compressionQuality)")
        
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            print("DEBUG: Image conversion to JPEG data failed")
            completion(.failure(ImageUploadError.imageConversionFailed))
            return
        }
        
        print("DEBUG: Image data size: \(imageData.count) bytes")
        
        // Create unique filename with timestamp to avoid conflicts
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "\(UUID().uuidString)-\(timestamp).jpg"
        let storageRef = storage.reference().child("\(path)/\(filename)")
        
        print("DEBUG: Storage path: \(path)/\(filename)")
        
        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload with retry logic
        uploadWithRetry(imageData: imageData, storageRef: storageRef, metadata: metadata, retryCount: 0, completion: completion)
    }
    
    // Upload profile picture (convenience method)
    func uploadProfilePicture(image: UIImage, userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("DEBUG: uploadProfilePicture called")
        print("DEBUG: User ID: \(userId)")
        
        let path = "profile_images/\(userId)"
        print("DEBUG: Storage path: \(path)")
        
        uploadImage(image: image, path: path, completion: completion)
    }
    
    // Private helper method with retry logic
    private func uploadWithRetry(imageData: Data, storageRef: StorageReference, metadata: StorageMetadata, retryCount: Int, completion: @escaping (Result<String, Error>) -> Void) {
        print("DEBUG: uploadWithRetry called, attempt \(retryCount + 1)")
        
        let uploadTask = storageRef.putData(imageData, metadata: metadata) { (resultMetadata, error) in
            if let error = error {
                print("DEBUG: Upload error: \(error.localizedDescription), attempt \(retryCount + 1) of \(self.maxRetries)")
                
                // Implement exponential backoff for retries
                if retryCount < self.maxRetries {
                    let delaySeconds = pow(2.0, Double(retryCount)) // 1, 2, 4, 8, etc.
                    print("DEBUG: Retrying upload in \(delaySeconds) seconds")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) {
                        self.uploadWithRetry(
                            imageData: imageData,
                            storageRef: storageRef,
                            metadata: metadata,
                            retryCount: retryCount + 1,
                            completion: completion
                        )
                    }
                    return
                }
                
                completion(.failure(error))
                return
            }
            
            // Get download URL
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("DEBUG: Failed to get download URL: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let downloadURL = url else {
                    print("DEBUG: No download URL returned")
                    completion(.failure(ImageUploadError.downloadURLFailed))
                    return
                }
                
                print("DEBUG: Download URL obtained: \(downloadURL.absoluteString)")
                
                // Cache URL locally for faster access
                self.cacheImageURL(url: downloadURL.absoluteString, imagePath: storageRef.fullPath)
                
                // Save URL to document directory as backup
                self.saveURLToFile(url: downloadURL.absoluteString, imagePath: storageRef.fullPath)
                
                completion(.success(downloadURL.absoluteString))
            }
        }
        
        // Add progress monitoring
        uploadTask.observe(.progress) { snapshot in
            guard let taskProgress = snapshot.progress else { return }
            let percentComplete = 100.0 * Double(taskProgress.completedUnitCount) / Double(taskProgress.totalUnitCount)
            print("DEBUG: Upload is \(percentComplete)% complete")
            
            // Notify progress via NotificationCenter if needed
            NotificationCenter.default.post(
                name: Notification.Name("ImageUploadProgress"),
                object: nil,
                userInfo: ["progress": percentComplete, "path": storageRef.fullPath]
            )
        }
    }
    
    // Cache image URL mapping in UserDefaults
    private func cacheImageURL(url: String, imagePath: String) {
        let key = "image_url_\(imagePath.replacingOccurrences(of: "/", with: "_"))"
        UserDefaults.standard.set(url, forKey: key)
    }
    
    // Retrieve cached URL from UserDefaults
    func getCachedURL(for imagePath: String) -> String? {
        let key = "image_url_\(imagePath.replacingOccurrences(of: "/", with: "_"))"
        return UserDefaults.standard.string(forKey: key)
    }
    
    // Save URL to document directory as backup
    private func saveURLToFile(url: String, imagePath: String) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent("image_urls.plist")
        
        var urlsDict: [String: String] = [:]
        
        // Load existing dictionary if available
        if let data = try? Data(contentsOf: fileURL),
           let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String] {
            urlsDict = dict
        }
        
        // Add or update URL mapping
        urlsDict[imagePath] = url
        
        // Save back to file
        if let data = try? PropertyListSerialization.data(fromPropertyList: urlsDict, format: .xml, options: 0) {
            try? data.write(to: fileURL)
        }
    }
    
    // Delete image from storage
    func deleteImage(at path: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let storageRef = storage.reference().child(path)
        
        storageRef.delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Remove from cache
                let key = "image_url_\(path.replacingOccurrences(of: "/", with: "_"))"
                UserDefaults.standard.removeObject(forKey: key)
                
                completion(.success(()))
            }
        }
    }
}
