import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    func save(key: String, data: Data) -> Bool {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ] as [String: Any]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func load(key: String) -> Data? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        return status == errSecSuccess ? result as? Data : nil
    }
    
    func delete(key: String) -> Bool {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ] as [String: Any]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    // Helper methods for storing common types
    
    func saveString(_ string: String, forKey key: String) -> Bool {
        guard let data = string.data(using: .utf8) else {
            return false
        }
        return save(key: key, data: data)
    }
    
    func loadString(forKey key: String) -> String? {
        guard let data = load(key: key) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    // For storing auth tokens or other sensitive information
    func saveAuthToken(_ token: String) -> Bool {
        return saveString(token, forKey: "auth_token")
    }
    
    func getAuthToken() -> String? {
        return loadString(forKey: "auth_token")
    }
    
    // For storing secure credentials
    func saveCredentials(email: String, password: String) -> Bool {
        // IMPORTANT: Storing passwords directly is not recommended
        // This is provided for demonstration only
        // In production, store authentication tokens instead
        let credentials = "\(email):\(password)"
        return saveString(credentials, forKey: "credentials")
    }
    
    func getCredentials() -> (email: String, password: String)? {
        guard let credentialsString = loadString(forKey: "credentials") else {
            return nil
        }
        
        let components = credentialsString.split(separator: ":")
        guard components.count == 2 else {
            return nil
        }
        
        return (String(components[0]), String(components[1]))
    }
}
