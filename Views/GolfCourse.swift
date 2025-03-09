import Foundation
import CoreLocation

struct GolfCourse: Codable, Identifiable {
    // Unique identifier computed from properties
    var id: String { Name + City + State }
    
    // Properties from JSON
    let Longitude: Double
    let Latitude: Double
    let Name: String
    let Street: String
    let City: String
    let Zip: String
    let State: String
    
    // Computed properties for easier access (matching original property names)
    var name: String { Name }
    var city: String { City }
    var state: String { State }
    var address: String { Street }
    var zipCode: String { Zip }
    
    // Coordinate for map display
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: Latitude, longitude: Longitude)
    }
    
    // Distance calculation helper
    func distance(to location: CLLocationCoordinate2D) -> CLLocationDistance {
        let courseLocation = CLLocation(latitude: Latitude, longitude: Longitude)
        let otherLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        return courseLocation.distance(from: otherLocation)
    }
}
