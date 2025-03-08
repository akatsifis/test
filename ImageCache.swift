//
//  ImageCache.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/6/25.
//


import UIKit

class ImageCache {
    static let shared = ImageCache()
    
    // Memory cache
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    
    // Maximum number of images to keep in memory
    private let maxMemoryCacheCount = 100
    
    // Cache expiration time (7 days in seconds)
    private let cacheExpirationSeconds: TimeInterval = 7 * 24 * 60 * 60
    
    private init() {
        // Set memory cache limits
        memoryCache.countLimit = maxMemoryCacheCount
        
        // Create cache directory if needed
        createCacheDirectoryIfNeeded()
        
        // Set up cleanup timer
        setupCleanupTimer()
        
        // Add notification observers for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    // Store image in cache (both memory and disk)
    func storeImage(_ image: UIImage, forKey key: String) {
        // Store in memory cache
        memoryCache.setObject(image, forKey: key as NSString)
        
        // Store on disk
        let cacheKey = sanitizeFileNameString(key)
        if let cacheDirectory = cacheDirectory, 
           let data = image.jpegData(compressionQuality: 0.8) {
            let fileURL = cacheDirectory.appendingPathComponent(cacheKey)
            try? data.write(to: fileURL)
            
            // Update last access time
            updateAccessTime(forKey: cacheKey)
        }
    }
    
    // Retrieve image from cache (checks memory first, then disk)
    func retrieveImage(forKey key: String) -> UIImage? {
        let cacheKey = sanitizeFileNameString(key)
        
        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: key as NSString) {
            // Update last access time
            updateAccessTime(forKey: cacheKey)
            return cachedImage
        }
        
        // If not in memory, check disk cache
        if let image = loadImageFromDisk(forKey: cacheKey) {
            // Add back to memory cache for faster access next time
            memoryCache.setObject(image, forKey: key as NSString)
            return image
        }
        
        return nil
    }
    
    // Remove image from cache
    func removeImage(forKey key: String) {
        let cacheKey = sanitizeFileNameString(key)
        
        // Remove from memory
        memoryCache.removeObject(forKey: key as NSString)
        
        // Remove from disk
        if let cacheDirectory = cacheDirectory {
            let fileURL = cacheDirectory.appendingPathComponent(cacheKey)
            try? fileManager.removeItem(at: fileURL)
            
            // Remove access time record
            removeAccessTime(forKey: cacheKey)
        }
    }
    
    // Clear all cached images
    func clearCache() {
        // Clear memory cache
        clearMemoryCache()
        
        // Clear disk cache
        clearDiskCache()
    }
    
    // MARK: - Private Methods
    
    // Get cache directory URL
    private var cacheDirectory: URL? {
        return fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("ImageCache")
    }
    
    // Create cache directory if it doesn't exist
    private func createCacheDirectoryIfNeeded() {
        guard let cacheDirectory = cacheDirectory else { return }
        
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create cache directory: \(error.localizedDescription)")
        }
    }
    
    // Load image from disk
    private func loadImageFromDisk(forKey key: String) -> UIImage? {
        guard let cacheDirectory = cacheDirectory else { return nil }
        
        let fileURL = cacheDirectory.appendingPathComponent(key)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            if let image = UIImage(data: data) {
                // Update access time
                updateAccessTime(forKey: key)
                return image
            }
        } catch {
            print("Error loading image from disk: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // Clear memory cache
    @objc private func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    // Clear disk cache
    private func clearDiskCache() {
        guard let cacheDirectory = cacheDirectory else { return }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in fileURLs where fileURL.pathExtension != "plist" {
                try fileManager.removeItem(at: fileURL)
            }
            
            // Also clear access times
            let accessTimesURL = cacheDirectory.appendingPathComponent("accessTimes.plist")
            try? fileManager.removeItem(at: accessTimesURL)
        } catch {
            print("Error clearing disk cache: \(error.localizedDescription)")
        }
    }
    
    // Sanitize file name string
    private func sanitizeFileNameString(_ string: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        let sanitized = string.components(separatedBy: invalidCharacters).joined(separator: "_")
        
        // Hash long strings to prevent filename length issues
        if sanitized.count > 50 {
            let hash = sanitized.hash
            return "\(abs(hash))"
        }
        
        return sanitized
    }
    
    // MARK: - Cache Expiration and Cleanup
    
    // Set up timer to clean up expired cache entries
    private func setupCleanupTimer() {
        // Clean expired cache once a day
        Timer.scheduledTimer(timeInterval: 24 * 60 * 60, target: self, selector: #selector(cleanupExpiredItems), userInfo: nil, repeats: true)
    }
    
    // Clean up expired items
    @objc private func cleanupExpiredItems() {
        guard let cacheDirectory = cacheDirectory else { return }
        guard let accessTimes = getAccessTimes() else { return }
        
        let now = Date().timeIntervalSince1970
        var keysToRemove: [String] = []
        
        for (key, lastAccessTime) in accessTimes {
            // If item hasn't been accessed for the expiration time, remove it
            if now - lastAccessTime > cacheExpirationSeconds {
                keysToRemove.append(key)
            }
        }
        
        // Remove expired items
        for key in keysToRemove {
            let fileURL = cacheDirectory.appendingPathComponent(key)
            try? fileManager.removeItem(at: fileURL)
            removeAccessTime(forKey: key)
        }
    }
    
    // Track last access time for cache items
    private func updateAccessTime(forKey key: String) {
        guard let cacheDirectory = cacheDirectory else { return }
        
        var accessTimes = getAccessTimes() ?? [:]
        
        // Update access time for this key
        accessTimes[key] = Date().timeIntervalSince1970
        
        // Save updated access times
        let accessTimesURL = cacheDirectory.appendingPathComponent("accessTimes.plist")
        (accessTimes as NSDictionary).write(to: accessTimesURL, atomically: true)
    }
    
    // Remove access time record for a key
    private func removeAccessTime(forKey key: String) {
        guard let cacheDirectory = cacheDirectory else { return }
        
        var accessTimes = getAccessTimes() ?? [:]
        
        // Remove this key
        accessTimes.removeValue(forKey: key)
        
        // Save updated access times
        let accessTimesURL = cacheDirectory.appendingPathComponent("accessTimes.plist")
        (accessTimes as NSDictionary).write(to: accessTimesURL, atomically: true)
    }
    
    // Get all access times
    private func getAccessTimes() -> [String: TimeInterval]? {
        guard let cacheDirectory = cacheDirectory else { return nil }
        
        let accessTimesURL = cacheDirectory.appendingPathComponent("accessTimes.plist")
        
        if let dict = NSDictionary(contentsOf: accessTimesURL) as? [String: TimeInterval] {
            return dict
        }
        
        return [:]
    }
}