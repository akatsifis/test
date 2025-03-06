//
//  EnhancedPlayNowView.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/5/25.
//


import SwiftUI
import HealthKit
import Firebase

struct EnhancedPlayNowView: View {
    // MARK: - State
    @State private var golfCourse = ""
    @State private var holeCount = 18
    @State private var nineHoleSection = "front" // New state for front/back 9 selection
    @State private var transportMode = TransportMode.walking
    @State private var isTracking = false
    @State private var currentHole = 1
    @State private var scores: [Int] = Array(repeating: 0, count: 18)
    @State private var notes: [String] = Array(repeating: "", count: 18)
    @State private var showConfirmation = false
    @State private var showSummary = false
    @State private var roundCompleted = false
    @State private var showLeagueSubmission = false
    @State private var selectedLeague: String = ""
    
    // MARK: - Health Data
    @State private var startTime: Date?
    @State private var stepCount = 0
    @State private var distance = 0.0
    @State private var calories = 0.0
    
    // MARK: - Environment Objects
    @EnvironmentObject var workoutManager: iOSWorkoutManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    
    // MARK: - Health Store
    private let healthStore = HKHealthStore()
    
    // MARK: - List of courses
    let courses = ["Armitage Golf Club", "Rich Valley Golf", "Range End",
                  "Cumberland Golf Club", "Mayapple Golf Club", "Dauphin Highlands"]
    
    enum TransportMode: String, CaseIterable, Identifiable {
        case walking = "Walking"
        case cart = "Riding"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .walking: return "figure.walk"
            case .cart: return "car.fill"
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("Golf")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .position(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2) // Center position
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.7), Color.black.opacity(0.4)]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .ignoresSafeArea()
                
                if !roundCompleted {
                    if !isTracking {
                        // Initial setup screen
                        setupView(screenWidth: geometry.size.width)
                    } else {
                        // Active round screen
                        activeRoundView(screenWidth: geometry.size.width)
                    }
                } else {
                    // Round summary screen
                    roundSummaryView(screenWidth: geometry.size.width)
                }
            }
            .alert(isPresented: $showConfirmation) {
                Alert(
                    title: Text("Finish Round"),
                    message: Text("Are you sure you want to finish this round?"),
                    primaryButton: .destructive(Text("Finish")) {
                        finishRound()
                    },
                    secondaryButton: .cancel()
                )
            }
            .onAppear {
                requestHealthKitPermissions()
            }
        }
        .sheet(isPresented: $showLeagueSubmission) {
            LeagueSubmissionView(
                score: calculateTotalScore(),
                course: golfCourse,
                holeCount: holeCount,
                steps: stepCount,
                distance: distance,
                calories: calories,
                onSubmit: { leagueId in
                    submitScoreToLeague(leagueId: leagueId)
                    showLeagueSubmission = false
                }
            )
        }
    }
    
    // MARK: - Setup View
    func setupView(screenWidth: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 25) {
                Text("New Round")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer().frame(height: 20)
                
                // Course Selection
                VStack(alignment: .leading, spacing: 10) {
                    Text("SELECT COURSE")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Picker("Course", selection: $golfCourse) {
                        Text("Select a course").tag("")
                        ForEach(courses, id: \.self) { course in
                            Text(course).tag(course)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                }
                .frame(width: screenWidth * 0.9)
                .frame(maxWidth: .infinity, alignment: .center)
                
                // Hole Count
                VStack(alignment: .leading, spacing: 10) {
                    Text("NUMBER OF HOLES")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Picker("Holes", selection: $holeCount) {
                        Text("9 Holes").tag(9)
                        Text("18 Holes").tag(18)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                }
                .frame(width: screenWidth * 0.9)
                .frame(maxWidth: .infinity, alignment: .center)
                
                // Nine Hole Section (Front/Back) - Only show when 9 holes is selected
                if holeCount == 9 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("WHICH NINE?")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Picker("Nine", selection: $nineHoleSection) {
                            Text("Front 9").tag("front")
                            Text("Back 9").tag("back")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .frame(width: screenWidth * 0.9)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
                    .animation(.easeInOut, value: holeCount)
                }
                
                // Transport Mode
                VStack(alignment: .leading, spacing: 10) {
                    Text("HOW ARE YOU PLAYING?")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    VStack(spacing: 12) {
                        ForEach(TransportMode.allCases) { mode in
                            TransportButton(
                                mode: mode,
                                isSelected: transportMode == mode,
                                action: { transportMode = mode },
                                screenWidth: screenWidth * 0.9
                            )
                        }
                    }
                }
                .frame(width: screenWidth * 0.9)
                .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer().frame(height: 20)
                
                // Start Button
                Button(action: {
                    print("Start button tapped")
                    startRound()
                }) {
                    Text("Start Round")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: screenWidth * 0.9)
                        .padding(.vertical, 16)
                        .background(golfCourse.isEmpty ? Color.gray : Color.green)
                        .cornerRadius(15)
                        .shadow(radius: 5)
                }
                .disabled(golfCourse.isEmpty)
                .padding(.bottom, 30)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Active Round View
    func activeRoundView(screenWidth: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top section with course name and stats
                VStack(spacing: 10) {
                    Text(golfCourse)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: screenWidth * 0.9, alignment: .center)
                    
                    // Stats bar
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            StatBox(icon: "figure.walk", value: "\(stepCount)", label: "Steps", width: (screenWidth * 0.9 - 30) / 2)
                            StatBox(icon: "location.fill", value: "\(holeCount)", label: "Holes", width: (screenWidth * 0.9 - 30) / 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        HStack(spacing: 12) {
                            StatBox(icon: "flame.fill", value: "\(Int(calories))", label: "Cal", width: (screenWidth * 0.9 - 30) / 2)
                            StatBox(icon: "arrow.forward", value: String(format: "%.1f", distance), label: "Miles", width: (screenWidth * 0.9 - 30) / 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(15)
                .frame(width: screenWidth * 0.9)
                .frame(maxWidth: .infinity, alignment: .center)
                
                // Current hole display
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 140, height: 140)
                        .shadow(radius: 10)
                    
                    VStack {
                        Text("HOLE")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("\(currentHole)")
                            .font(.system(size: 60, weight: .bold))
                    }
                    .foregroundColor(.white)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .center)
                
                // Score input
                VStack(spacing: 10) {
                    Text("SCORE")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 20) {
                        Button(action: { decrementScore() }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                        
                        Text("\(scores[currentHole - 1])")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 80)
                        
                        Button(action: { incrementScore() }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(15)
                    .frame(width: screenWidth * 0.9)
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer().frame(height: 20)
                
                // Navigation buttons
                VStack(spacing: 15) {
                    Button(action: { nextHole() }) {
                        HStack {
                            Text(currentHole == holeCount ? "Finish Round" : "Next Hole")
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .frame(width: screenWidth * 0.9)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    Button(action: { previousHole() }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Previous Hole")
                        }
                        .padding()
                        .frame(width: screenWidth * 0.9)
                        .background(currentHole > 1 ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(currentHole <= 1)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.bottom, 30)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 20)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            startHealthKitMonitoring()
        }
    }
    
    // MARK: - Round Summary View
    func roundSummaryView(screenWidth: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Round Complete!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                // Course and date info
                VStack(spacing: 5) {
                    Text(golfCourse)
                        .font(.title2)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text(formattedDate())
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                // Total score
                VStack {
                    Text("TOTAL SCORE")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("\(calculateTotalScore())")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .center)
                
                // Health stats
                VStack(spacing: 12) {
                    Text("ACTIVITY STATS")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            StatBox(icon: "clock", value: formattedDuration(), label: "Duration", width: (screenWidth * 0.9 - 24) / 2)
                            StatBox(icon: "flame.fill", value: "\(Int(calories))", label: "Calories", width: (screenWidth * 0.9 - 24) / 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        HStack(spacing: 12) {
                            StatBox(icon: "figure.walk", value: "\(stepCount)", label: "Steps", width: (screenWidth * 0.9 - 24) / 2)
                            StatBox(icon: "arrow.forward", value: String(format: "%.1f", distance), label: "Miles", width: (screenWidth * 0.9 - 24) / 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(15)
                .frame(width: screenWidth * 0.9)
                .frame(maxWidth: .infinity, alignment: .center)
                
                // Scorecard
                VStack(spacing: 10) {
                    Text("SCORECARD")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    VStack(spacing: 0) {
                        // Header row
                        HStack {
                            Text("Hole")
                                .frame(width: 60, alignment: .leading)
                            
                            Spacer()
                            
                            Text("Score")
                                .frame(width: 60, alignment: .trailing)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                        .background(Color.gray.opacity(0.5))
                        .foregroundColor(.white)
                        
                        // Score rows
                        ForEach(0..<holeCount, id: \.self) { index in
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Hole \(index + 1 + (holeCount == 9 && nineHoleSection == "back" ? 9 : 0))")
                                        .frame(width: 60, alignment: .leading)
                                    
                                    Spacer()
                                    
                                    Text("\(scores[index])")
                                        .frame(width: 60, alignment: .trailing)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal)
                                
                                if index < holeCount - 1 {
                                    Divider()
                                        .background(Color.gray.opacity(0.3))
                                }
                            }
                        }
                    }
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .frame(width: screenWidth * 0.9)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                // Action buttons
                VStack(spacing: 15) {
                    Button(action: {
                        saveRoundToFirebase()
                    }) {
                        Text("Save Round")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: screenWidth * 0.9)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(15)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    Button(action: {
                        showLeagueSubmission = true
                    }) {
                        Text("Submit to League")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: screenWidth * 0.9)
                            .padding(.vertical, 16)
                            .background(Color.orange)
                            .cornerRadius(15)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    Button(action: {
                        shareRound()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Results")
                        }
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: screenWidth * 0.9)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(15)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    Button(action: {
                        resetAndStartNewRound()
                    }) {
                        Text("New Round")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .frame(width: screenWidth * 0.9)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(15)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.bottom, 30)
            }
            .padding(.top, 30)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Component Views
    
    struct TransportButton: View {
        let mode: TransportMode
        let isSelected: Bool
        let action: () -> Void
        let screenWidth: CGFloat
        
        var body: some View {
            Button(action: action) {
                HStack {
                    Image(systemName: mode.icon)
                        .font(.system(size: 24))
                        .frame(width: 30)
                    
                    Text(mode.rawValue)
                        .font(.system(size: 16))
                    
                    Spacer()
                }
                .padding()
                .frame(width: screenWidth)
                .background(isSelected ? Color.blue : Color.white)
                .foregroundColor(isSelected ? .white : .black)
                .cornerRadius(12)
                .shadow(radius: isSelected ? 5 : 0)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    struct StatBox: View {
        let icon: String
        let value: String
        let label: String
        let width: CGFloat
        
        var body: some View {
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Text(value)
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding()
            .frame(width: width)
            .background(Color.white)
            .cornerRadius(10)
        }
    }
    
    // MARK: - Functions
    
    private func startRound() {
        print("Starting round with: Course: \(golfCourse), Holes: \(holeCount), Section: \(nineHoleSection)")
        isTracking = true
        startTime = Date()
        
        // Set starting hole based on front/back selection
        if holeCount == 9 && nineHoleSection == "back" {
            currentHole = 10
        } else {
            currentHole = 1
        }
        
        // Reset scores
        scores = Array(repeating: 0, count: 18)
        notes = Array(repeating: "", count: 18)
        
        // Start workout tracking
        workoutManager.startWorkoutOnWatch()
    }
    
    private func incrementScore() {
        let scoreIndex = currentHole - 1
        if scores[scoreIndex] < 10 {
            scores[scoreIndex] += 1
            print("Incremented score for hole \(currentHole) to \(scores[scoreIndex])")
        }
    }
    
    private func decrementScore() {
        let scoreIndex = currentHole - 1
        if scores[scoreIndex] > 0 {
            scores[scoreIndex] -= 1
            print("Decremented score for hole \(currentHole) to \(scores[scoreIndex])")
        }
    }
    
    private func nextHole() {
        if holeCount == 9 && nineHoleSection == "back" {
            if currentHole < 18 {
                currentHole += 1
            } else {
                showConfirmation = true
            }
        } else {
            if currentHole < holeCount {
                currentHole += 1
            } else {
                showConfirmation = true
            }
        }
    }
    
    private func previousHole() {
        if holeCount == 9 && nineHoleSection == "back" {
            if currentHole > 10 {
                currentHole -= 1
            }
        } else {
            if currentHole > 1 {
                currentHole -= 1
            }
        }
    }
    
    private func finishRound() {
        // Stop activity monitoring
        workoutManager.endWorkoutOnWatch()
        stopHealthKitMonitoring()
        
        // Mark as completed
        roundCompleted = true
    }
    
    private func saveRoundToFirebase() {
        guard let userId = Auth.auth().currentUser?.uid else {
            // Handle error - user not logged in
            return
        }
        
        let roundData = createRoundData()
        
        // Create a score entry
        let scoreEntry = Models.User.Score(
            id: UUID().uuidString,
            course: golfCourse,
            score: calculateTotalScore(),
            date: Date(),
            holesPlayed: "\(holeCount) Holes" + (holeCount == 9 ? " (\(nineHoleSection == "front" ? "Front" : "Back"))" : ""),
            steps: stepCount,
            distance: distance,
            caloriesBurned: calories
        )
        
        if networkMonitor.isConnected {
            // Save directly to Firebase
            UserService.shared.addScore(score: scoreEntry) { result in
                switch result {
                case .success(_):
                    print("Round saved successfully")
                case .failure(let error):
                    print("Error saving round: \(error.localizedDescription)")
                }
            }
        } else {
            // Save offline
            if let userId = Auth.auth().currentUser?.uid {
                FirestoreManager.shared.saveScoreOffline(score: scoreEntry, userId: userId) { result in
                    switch result {
                    case .success(_):
                        print("Round saved offline")
                    case .failure(let error):
                        print("Error saving round offline: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func submitScoreToLeague(leagueId: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        let db = Firestore.firestore()
        
        // Create a new round document in the league's rounds collection
        let roundData: [String: Any] = [
            "userId": userId,
            "course": golfCourse,
            "score": calculateTotalScore(),
            "date": Timestamp(date: Date()),
            "holeCount": holeCount,
            "nineHoleSection": holeCount == 9 ? nineHoleSection : "full",
            "transportMode": transportMode.rawValue,
            "healthData": [
                "steps": stepCount,
                "distance": distance,
                "calories": calories
            ]
        ]
        
        db.collection("leagues").document(leagueId).collection("rounds").addDocument(data: roundData) { error in
            if let error = error {
                print("Error submitting score to league: \(error.localizedDescription)")
            } else {
                print("Score successfully submitted to league")
            }
        }
    }
    
    private func shareRound() {
        var shareText = "I just finished a round at \(golfCourse)!\n"
        shareText += "Total Score: \(calculateTotalScore())\n"
        
        if holeCount == 9 {
            shareText += "Holes Played: \(holeCount) (\(nineHoleSection == "front" ? "Front 9" : "Back 9"))\n"
        } else {
            shareText += "Holes Played: \(holeCount)\n"
        }
        
        shareText += "Steps: \(stepCount)\n"
        shareText += "Calories Burned: \(Int(calories))\n"
        
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        // Present the activity view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func createRoundData() -> [String: Any] {
        let duration = calculateDuration()
        
        var roundData: [String: Any] = [
            "course": golfCourse,
            "date": Date(),
            "duration": duration,
            "holeCount": holeCount,
            "scores": scores,
            "notes": notes,
            "totalScore": calculateTotalScore(),
            "transportMode": transportMode.rawValue,
            "healthData": [
                "steps": stepCount,
                "distance": distance,
                "calories": calories
            ]
        ]
        
        if holeCount == 9 {
            roundData["nineHoleSection"] = nineHoleSection
        }
        
        return roundData
    }
    
    private func resetAndStartNewRound() {
        // Reset state
        golfCourse = ""
        holeCount = 18
        nineHoleSection = "front"
        transportMode = .walking
        isTracking = false
        currentHole = 1
        scores = Array(repeating: 0, count: 18)
        notes = Array(repeating: "", count: 18)
        roundCompleted = false
        
        // Reset health data
        startTime = nil
        stepCount = 0
        distance = 0.0
        calories = 0.0
    }
    
    // MARK: - Helper Functions
    
    private func calculateTotalScore() -> Int {
        if holeCount == 9 && nineHoleSection == "back" {
            return scores.prefix(9).reduce(0, +)
        } else {
            return scores.prefix(holeCount).reduce(0, +)
        }
    }
    
    private func calculateDuration() -> TimeInterval {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }
    
    private func formattedDuration() -> String {
        let duration = calculateDuration()
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - HealthKit Functions
    
    private func requestHealthKitPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if !success {
                print("HealthKit authorization failed: \(String(describing: error))")
            }
        }
    }
    
    private func startHealthKitMonitoring() {
        // This would be expanded to actually query the HealthKit store
        // and set up observers for real-time updates
        
        // For this example, we'll simulate health data updates with a timer
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            DispatchQueue.main.async {
                // Simulate health data changes based on transport mode
                if transportMode == .walking {
                    stepCount += Int.random(in: 50...200)
                    distance += Double.random(in: 0.02...0.1)
                    calories += Double.random(in: 5...20)
                } else {
                    stepCount += Int.random(in: 5...30)
                    distance += Double.random(in: 0.02...0.1)
                    calories += Double.random(in: 1...10)
                }
            }
        }
    }
    
    private func stopHealthKitMonitoring() {
        // This would stop any active observers or queries
    }
}

struct EnhancedPlayNowView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedPlayNowView()
            .environmentObject(iOSWorkoutManager())
            .environmentObject(NetworkMonitor())
    }
}
