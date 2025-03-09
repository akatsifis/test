//
//  GolfCourseDataManager.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/8/25.
//

import Foundation
import CoreLocation

class GolfCourseDataManager {
    // Singleton instance
    static let shared = GolfCourseDataManager()
    
    // Cached courses
    private var courses: [GolfCourse] = []
    
    // Load all courses from JSON
    func loadCourses() -> [GolfCourse] {
        // Return cached courses if available
        if !courses.isEmpty {
            return courses
        }
        
        // Load from bundle
        guard let url = Bundle.main.url(forResource: "golfCourses", withExtension: "json") else {
            print("Error: golfCourses.json not found in bundle")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            courses = try JSONDecoder().decode([GolfCourse].self, from: data)
            return courses
        } catch {
            print("Error loading golf courses: \(error)")
            return []
        }
    }
    
    // Search courses by name and state
    func searchCourses(query: String, state: String? = nil) -> [GolfCourse] {
        let courses = loadCourses()
        
        return courses.filter { course in
            // Filter by state if provided
            if let state = state, !state.isEmpty, course.State.lowercased() != state.lowercased() {
                return false
            }
            
            // Filter by name if query is not empty
            if !query.isEmpty {
                return course.Name.lowercased().contains(query.lowercased())
            }
            
            return true
        }
    }
    
    // Find nearby courses
    func findNearbyCourses(location: CLLocationCoordinate2D, radius: CLLocationDistance = 50000) -> [GolfCourse] {
        let courses = loadCourses()
        
        return courses.filter { course in
            course.distance(to: location) <= radius
        }.sorted { course1, course2 in
            course1.distance(to: location) < course2.distance(to: location)
        }
    }
    
    // Get course by ID
    func getCourse(byId id: String) -> GolfCourse? {
        return loadCourses().first { $0.id == id }
    }
    
    // Get courses by state
    func getCourses(inState state: String) -> [GolfCourse] {
        return loadCourses().filter { $0.State.lowercased() == state.lowercased() }
    }
}
