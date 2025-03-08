import SwiftUI
import Firebase

@main
struct AldoApp: App {
    @StateObject private var workoutManager = iOSWorkoutManager()
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var notificationManager = AldoNotificationManager.shared

    init() {
        // Initialize Firebase first, before any other Firebase service is used
        FirebaseApp.configure()
        
        // Configure Firestore settings after Firebase is initialized
        FirestoreManager.configureFirestore()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
                .environmentObject(authManager)
                .environmentObject(networkMonitor)
                .environmentObject(notificationManager)
        }
    }
}
