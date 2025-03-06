//
//  NetworkMonitor.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/5/25.
//


//
//  NetworkMonitor.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/4/25.
//


import Foundation
import Network
import FirebaseAuth

class NetworkMonitor: ObservableObject {
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    
    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown
    }
    
    init() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.determineConnectionType(path)
                
                // If connection is re-established, sync pending data
                if path.status == .satisfied {
                    self?.syncPendingData()
                }
            }
        }
        networkMonitor.start(queue: queue)
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    private func determineConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wired
        } else {
            connectionType = .unknown
        }
    }
    
    private func syncPendingData() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Sync pending scores
        FirestoreManager.shared.syncPendingScores(userId: userId) { result in
            switch result {
            case .success(let count):
                if count > 0 {
                    print("Successfully synced \(count) pending scores")
                    
                    // Clean up old synced data
                    FirestoreManager.shared.cleanupSyncedScores(userId: userId) { _ in }
                }
            case .failure(let error):
                print("Failed to sync pending scores: \(error.localizedDescription)")
            }
        }
    }
}
