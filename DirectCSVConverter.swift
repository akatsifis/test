//
//  DirectCSVConverter.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/8/25.
//


import Foundation
import CSV

class DirectCSVConverter {
    static func convert() {
        // Exact paths
        let csvPath = "/Users/andrew/Desktop/Aldo/Aldo/GolfCoursesUSA.csv"
        
        // Use Documents directory for JSON output (guaranteed writable)
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let jsonPath = documentsPath + "/golfCourses.json"
        
        print("CSV Path: \(csvPath)")
        print("JSON will be saved to: \(jsonPath)")
        
        do {
            // Check file exists
            guard FileManager.default.fileExists(atPath: csvPath) else {
                print("ERROR: CSV file not found at \(csvPath)")
                return
            }
            
            // Read CSV
            let stream = InputStream(fileAtPath: csvPath)!
            let csv = try CSVReader(stream: stream, hasHeaderRow: false)
            
            var courses: [[String: Any]] = []
            var rowCount = 0
            
            while let row = csv.next() {
                rowCount += 1
                guard row.count >= 4 else { continue }
                
                // Basic parsing
                let longitude = Double(row[0]) ?? 0
                let latitude = Double(row[1]) ?? 0
                let nameLocationString = row[2]
                let detailsString = row[3]
                
                // Simple name/location parsing
                let parts = nameLocationString.components(separatedBy: "-")
                var name = nameLocationString
                var city = ""
                var state = ""
                
                if parts.count > 1 {
                    name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let locationPart = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let cityState = locationPart.components(separatedBy: ",")
                    if cityState.count > 1 {
                        city = cityState[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        state = cityState[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                // Create basic course object
                let course: [String: Any] = [
                    "id": UUID().uuidString,
                    "name": name,
                    "city": city, 
                    "state": state,
                    "details": detailsString,
                    "latitude": latitude,
                    "longitude": longitude
                ]
                
                courses.append(course)
                
                if rowCount % 1000 == 0 {
                    print("Processed \(rowCount) rows")
                }
            }
            
            print("Completed processing \(rowCount) rows")
            print("Creating JSON with \(courses.count) courses")
            
            // Write JSON
            let jsonData = try JSONSerialization.data(withJSONObject: courses, options: .prettyPrinted)
            try jsonData.write(to: URL(fileURLWithPath: jsonPath))
            
            print("✅ JSON file created successfully at: \(jsonPath)")
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
        }
    }
}