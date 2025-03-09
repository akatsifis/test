import SwiftUI
import CoreLocation

struct CourseSearchView: View {
    @Binding var selectedCourse: GolfCourse?
    @State private var searchText = ""
    @State private var selectedState = ""
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var showSearchMode = false
    
    // Use the app-wide location manager instead of creating a new one
    @EnvironmentObject private var locationManager: AppLocationManager
    
    let states = ["", "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
                 "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
                 "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
                 "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
                 "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"]
    
    var displayedCourses: [GolfCourse] {
        if !showSearchMode, let _ = locationManager.currentLocation {
            return locationManager.findNearbyCourses()
        } else {
            return GolfCourseDataManager.shared.searchCourses(query: searchText, state: selectedState)
        }
    }
    
    var body: some View {
        VStack {
            // Mode toggle
            Picker("View Mode", selection: $showSearchMode) {
                Text("Nearby Courses").tag(false)
                Text("Search").tag(true)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Search UI (only shown in search mode)
            if showSearchMode {
                HStack {
                    TextField("Search courses", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.leading)
                    
                    Picker("State", selection: $selectedState) {
                        ForEach(states, id: \.self) { state in
                            Text(state.isEmpty ? "All States" : state)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 120)
                    .padding(.trailing)
                }
                .padding(.vertical, 8)
            } else {
                // Location status (only shown in nearby mode)
                if locationManager.isLoadingLocation {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 4)
                        Text("Finding courses near you...")
                    }
                    .padding(8)
                } else if locationManager.currentLocation == nil {
                    Button(action: {
                        locationManager.requestLocationIfNeeded()
                    }) {
                        Label("Get Nearby Courses", systemImage: "location")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    .padding(8)
                } else {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)
                        Text("Showing courses near your location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                }
            }

            if isLoading {
                ProgressView()
                    .padding()
            } else if locationManager.currentLocation == nil && !showSearchMode {
                // First-time location permission view
                VStack(spacing: 20) {
                    Image(systemName: "location.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Find Golf Courses Near You")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Allow location access to see courses in your area, or use search to find specific courses.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        locationManager.requestLocationIfNeeded()
                    }) {
                        Text("Allow Location Access")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
                }
                .padding()
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            } else if displayedCourses.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No courses found")
                        .font(.headline)
                    Text(showSearchMode ? "Try a different search" : "No courses found nearby. Try searching instead.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding()
            } else {
                List(displayedCourses, id: \.id) { course in
                    Button(action: {
                        selectedCourse = course
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(course.Name)
                                    .font(.headline)
                                Text("\(course.City), \(course.State)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if !showSearchMode, let location = locationManager.currentLocation {
                                    if let distance = locationManager.distance(to: course.coordinate) {
                                        // Convert meters to miles
                                        let miles = distance / 1609.344
                                        Text(String(format: "%.1f miles away", miles))
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Select a Course")
        .onAppear {
            loadData()
            // Try to get location automatically on first load
            locationManager.requestLocationIfNeeded()
        }
    }
    
    // Environment value to dismiss the sheet
    @Environment(\.presentationMode) private var presentationMode
    
    private func loadData() {
        DispatchQueue.global().async {
            let courses = GolfCourseDataManager.shared.loadCourses()
            DispatchQueue.main.async {
                if courses.isEmpty {
                    errorMessage = "Unable to load courses"
                }
                isLoading = false
            }
        }
    }
}
