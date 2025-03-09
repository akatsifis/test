//
//  AppLocationManager.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/8/25.
//


import Foundation
import CoreLocation

class AppLocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoadingLocation = false
    @Published var lastError: Error?
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 500 // Update if moved more than 500 meters
        
        // Check current status and request authorization if needed
        authorizationStatus = locationManager.authorizationStatus
        
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startLocationUpdates()
        }
    }
    
    func requestLocationIfNeeded() {
        if currentLocation == nil && !isLoadingLocation {
            isLoadingLocation = true
            
            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                locationManager.requestLocation() // Request one-time update
            } else {
                locationManager.requestWhenInUseAuthorization()
            }
        }
    }
    
    func startLocationUpdates() {
        isLoadingLocation = true
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        isLoadingLocation = false
        locationManager.stopUpdatingLocation()
    }
    
    // Calculate distance between locations
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let currentLocation = currentLocation else { return nil }
        
        let location1 = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        return location1.distance(from: location2)
    }
    
    // Find courses near current location
    func findNearbyCourses() -> [GolfCourse] {
        guard let location = currentLocation else { return [] }
        return GolfCourseDataManager.shared.findNearbyCourses(location: location)
    }
}

// MARK: - CLLocationManagerDelegate
extension AppLocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.startLocationUpdates()
            case .denied, .restricted:
                self.isLoadingLocation = false
                self.lastError = NSError(domain: "LocationError", 
                                        code: 1, 
                                        userInfo: [NSLocalizedDescriptionKey: "Location access denied"])
            default:
                break
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            if let location = locations.last {
                self.currentLocation = location.coordinate
                self.isLoadingLocation = false
                self.lastError = nil
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoadingLocation = false
            self.lastError = error
            print("Location manager error: \(error.localizedDescription)")
        }
    }
}