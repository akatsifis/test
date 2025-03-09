import SwiftUI
import Firebase

@main
struct AldoApp: App {
    // Initialize environment objects
    @StateObject private var locationManager = AppLocationManager()
    @StateObject private var workoutManager = iOSWorkoutManager()
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var notificationManager = AldoNotificationManager()
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Any other app initialization
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(workoutManager)
                .environmentObject(networkMonitor)
                .environmentObject(authManager)
                .environmentObject(notificationManager)
                .onAppear {
                    // Request location permissions immediately on app launch
                    locationManager.requestLocationIfNeeded()
                }
        }
    }
}
