import Foundation
import CSV

class CSVConverter {
    static func convertCSVToJSON(csvPath: String, jsonPath: String) {
        print("CSV Converter: Starting conversion process")
        print("CSV path: \(csvPath)")
        print("JSON path: \(jsonPath)")
        
        // Check if CSV file exists
        guard FileManager.default.fileExists(atPath: csvPath) else {
            print("ERROR: CSV file does not exist at path: \(csvPath)")
            return
        }
        
        do {
            print("Opening CSV file...")
            let stream = InputStream(fileAtPath: csvPath)!
            let csv = try CSVReader(stream: stream, hasHeaderRow: false)
            
            var courses: [[String: Any]] = []
            
            print("Starting to read CSV rows...")
            var rowCount = 0
            
            while let row = csv.next() {
                rowCount += 1
                // Ensure we have all required fields
                guard row.count >= 4 else {
                    print("Skipping row \(rowCount): insufficient columns")
                    continue
                }
                
                // Extract data from row
                // Our format: longitude, latitude, name/location, details
                let longitude = Double(row[0]) ?? 0
                let latitude = Double(row[1]) ?? 0
                
                // Parse the name/location
                let nameLocationString = row[2]
                let nameLocationComponents = nameLocationString.components(separatedBy: "-")
                var name = nameLocationString
                var city = ""
                var state = ""
                
                if nameLocationComponents.count > 1 {
                    name = nameLocationComponents[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let locationPart = nameLocationComponents[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Try to extract city,state
                    let cityStateComponents = locationPart.components(separatedBy: ",")
                    if cityStateComponents.count > 1 {
                        city = cityStateComponents[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        state = cityStateComponents[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                // Parse the details string
                let detailsString = row[3]
                let isPublic = detailsString.contains("(Public)")
                
                // Extract hole count using regex
                let holes = extractHoles(from: detailsString)
                
                // Extract address
                var address = ""
                var zipCode = ""
                var phoneNumber: String? = nil
                
                // Attempt to parse details
                let components = detailsString.components(separatedBy: ", ")
                if components.count >= 3 {
                    address = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Try to find zip code component (usually contains city, state, and zip)
                    if let zipComponent = components.first(where: { $0.contains(" ") && ($0.contains(state) || $0.contains(",")) }) {
                        let zipParts = zipComponent.components(separatedBy: " ")
                        if let lastPart = zipParts.last, lastPart.count >= 5 {
                            zipCode = lastPart
                        }
                    }
                    
                    // Try to find phone number
                    if let phoneComponent = components.first(where: { $0.contains("(") && $0.contains(")") }) {
                        phoneNumber = phoneComponent.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                // Create the course dictionary
                let course: [String: Any] = [
                    "id": UUID().uuidString,
                    "name": name,
                    "city": city,
                    "state": state,
                    "isPublic": isPublic,
                    "holes": holes,
                    "address": address,
                    "zipCode": zipCode,
                    "phoneNumber": phoneNumber as Any,
                    "latitude": latitude,
                    "longitude": longitude
                ]
                
                courses.append(course)
                
                // Print progress occasionally
                if rowCount % 100 == 0 {
                    print("Processed \(rowCount) rows...")
                }
            }
            
            print("Finished reading CSV. Total rows processed: \(rowCount), valid courses: \(courses.count)")
            
            if courses.isEmpty {
                print("WARNING: No valid courses were extracted from the CSV")
                return
            }
            
            print("Converting to JSON...")
            let jsonData = try JSONSerialization.data(withJSONObject: courses, options: .prettyPrinted)
            
            print("Writing JSON to file: \(jsonPath)")
            try jsonData.write(to: URL(fileURLWithPath: jsonPath))
            
            print("Successfully converted CSV to JSON with \(courses.count) courses")
            print("JSON file should be available at: \(jsonPath)")
            
        } catch {
            print("ERROR in CSV conversion: \(error.localizedDescription)")
            print("Detailed error: \(error)")
        }
    }
    
    // Helper method to extract hole count from details string
    static func extractHoles(from detailsString: String) -> Int {
        // Look for pattern like "(9 Holes)" or "(18 Holes)"
        let pattern = "\\((\\d+)\\s+Holes\\)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = detailsString as NSString
        
        if let match = regex?.firstMatch(in: detailsString, options: [], range: NSRange(location: 0, length: nsString.length)) {
            let holeCountString = nsString.substring(with: match.range(at: 1))
            return Int(holeCountString) ?? 18 // Default to 18 if parsing fails
        }
        
        return 18 // Default to 18 holes
    }
    
    // Setup function to execute the conversion
    static func setupGolfCourses() {
        print("CSV Converter: Starting setup")
        
        // Try to use Documents directory for saving (more reliable in iOS)
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        
        // First option: try the original paths
        let csvPath = "/Users/andrew/Desktop/Aldo/Aldo/GolfCoursesUSA.csv"
        let jsonPath = "/Users/andrew/Desktop/Aldo/Aldo/golfCourses.json"
        
        // Check if the CSV file exists
        let fileExists = FileManager.default.fileExists(atPath: csvPath)
        print("CSV file exists at \(csvPath): \(fileExists)")
        
        if fileExists {
            print("Using original path for CSV: \(csvPath)")
            print("Using original path for JSON: \(jsonPath)")
            CSVConverter.convertCSVToJSON(csvPath: csvPath, jsonPath: jsonPath)
        } else {
            // Try alternative path - look in the app bundle
            if let bundlePath = Bundle.main.path(forResource: "GolfCoursesUSA", ofType: "csv") {
                print("Found CSV in app bundle: \(bundlePath)")
                let alternativeJsonPath = documentsPath + "/golfCourses.json"
                print("Using Documents directory for JSON: \(alternativeJsonPath)")
                CSVConverter.convertCSVToJSON(csvPath: bundlePath, jsonPath: alternativeJsonPath)
            } else {
                print("ERROR: Could not find CSV file in any location")
                
                // Print app bundle contents for debugging
                if let resourcePath = Bundle.main.resourcePath {
                    print("App bundle resource path: \(resourcePath)")
                    do {
                        let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                        print("Bundle contents: \(contents)")
                    } catch {
                        print("Error listing bundle contents: \(error)")
                    }
                }
            }
        }
    }
}
