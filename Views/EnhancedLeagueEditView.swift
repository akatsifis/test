//
//  EnhancedLeagueEditView.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/8/25.
//


import SwiftUI
import Firebase
import FirebaseFirestore
import PhotosUI

struct EnhancedLeagueEditView: View {
    let league: EnhancedLeague
    
    @State private var leagueName: String
    @State private var selectedCourse: String
    @State private var playDay: WeekDay
    @State private var playFrequency: String
    @State private var teeTime: Date
    @State private var leaguePhoto: UIImage?
    @State private var showingPhotoPicker = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingMemberSheet = false
    @Environment(\.presentationMode) var presentationMode
    
    // Member management
    @State private var members: [Models.User] = []
    @State private var searchQuery = ""
    @State private var searchResults: [Models.User] = []
    @State private var isSearching = false
    
    init(league: EnhancedLeague) {
        self.league = league
        _leagueName = State(initialValue: league.name)
        _selectedCourse = State(initialValue: league.course)
        _playDay = State(initialValue: league.playDay)
        _playFrequency = State(initialValue: league.schedule)
        
        // Default tee time to 9 AM if not set
        let defaultDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        _teeTime = State(initialValue: defaultDate)
        
        // If there's a next scheduled date, use its time
        if let nextDate = league.nextScheduledDate?.dateValue() {
            let components = Calendar.current.dateComponents([.hour, .minute], from: nextDate)
            if let hour = components.hour, let minute = components.minute {
                let time = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? defaultDate
                _teeTime = State(initialValue: time)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // League Photo Section
                Section(header: Text("LEAGUE PHOTO")) {
                    VStack {
                        if let leaguePhoto = leaguePhoto {
                            Image(uiImage: leaguePhoto)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                                .shadow(radius: 5)
                                .padding()
                        } else {
                            Image(systemName: "person.3.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .padding(10)
                                .foregroundColor(.white)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            showingPhotoPicker = true
                        }) {
                            Text("Change Picture")
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // League Details
                Section(header: Text("LEAGUE DETAILS")) {
                    TextField("League Name", text: $leagueName)
                    
                    Picker("Golf Course", selection: $selectedCourse) {
                        Text(selectedCourse).tag(selectedCourse)
                        // You can add more course options here
                        Text("Armitage Golf Club").tag("Armitage Golf Club")
                        Text("Rich Valley Golf").tag("Rich Valley Golf")
                        Text("Dauphin Highlands").tag("Dauphin Highlands")
                        Text("Cumberland Golf Club").tag("Cumberland Golf Club")
                        Text("Mayapple Golf Club").tag("Mayapple Golf Club")
                    }
                }
                
                // Schedule Section
                Section(header: Text("SCHEDULE")) {
                    Picker("Play Day", selection: $playDay) {
                        ForEach(WeekDay.allCases) { day in
                            Text(day.rawValue).tag(day)
                        }
                    }
                    
                    Picker("Frequency", selection: $playFrequency) {
                        Text("Weekly").tag("Weekly")
                        Text("Every 2 Weeks").tag("Every 2 Weeks")
                        Text("Monthly").tag("Monthly")
                    }
                    
                    DatePicker("Tee Time", selection: $teeTime, displayedComponents: .hourAndMinute)
                }
                
                // Member Management
                Section(header: Text("MEMBERS")) {
                    Button(action: {
                        fetchMembers()
                        showingMemberSheet = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Manage Members")
                        }
                    }
                }
                
                // Schedule Management
                Section(header: Text("SCHEDULE MANAGEMENT")) {
                    Button(action: {
                        generateSchedule()
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Generate Schedule")
                        }
                    }
                    .foregroundColor(.green)
                    
                    Button(action: {
                        endLeague()
                    }) {
                        HStack {
                            Image(systemName: "flag.checkered")
                            Text("End League")
                        }
                    }
                    .foregroundColor(.red)
                }
                
                // Save Button
                Section {
                    Button(action: saveChanges) {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(isLoading ? Color.gray : Color.blue)
                    .cornerRadius(10)
                    .disabled(isLoading)
                }
            }
            .navigationTitle("Edit League")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingPhotoPicker) {
                LeaguePHPickerView(image: $leaguePhoto)
            }
            .sheet(isPresented: $showingMemberSheet) {
                MemberManagementView(leagueId: league.id, members: $members)
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("League Update"), message: Text(alertMessage), dismissButton: .default(Text("OK")) {
                    if alertMessage.contains("successfully") {
                        presentationMode.wrappedValue.dismiss()
                    }
                })
            }
        }
    }
    
    private func fetchMembers() {
        // Only load members if not already loaded
        if members.isEmpty {
            isLoading = true
            
            let db = Firestore.firestore()
            let dispatchGroup = DispatchGroup()
            var fetchedMembers: [Models.User] = []
            
            for memberId in league.members {
                dispatchGroup.enter()
                
                db.collection("users").document(memberId).getDocument { snapshot, error in
                    defer { dispatchGroup.leave() }
                    
                    if let error = error {
                        print("Error fetching member data: \(error.localizedDescription)")
                        return
                    }
                    
                    if let snapshot = snapshot, snapshot.exists, let data = snapshot.data() {
                        if let member = Models.User.fromDictionary(data, id: snapshot.documentID) {
                            fetchedMembers.append(member)
                        }
                    }
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                self.members = fetchedMembers
                self.isLoading = false
            }
        }
    }
    
    private func saveChanges() {
        isLoading = true
        
        // Upload photo if changed
        if let photo = leaguePhoto {
            ImageUploadService.shared.uploadImage(
                image: photo,
                path: "league_images",
                compressionQuality: 0.7
            ) { result in
                switch result {
                case .success(let imageURL):
                    updateLeague(photoURL: imageURL)
                case .failure(let error):
                    print("Failed to upload photo: \(error.localizedDescription)")
                    updateLeague(photoURL: nil)
                }
            }
        } else {
            updateLeague(photoURL: nil)
        }
    }
    
    private func updateLeague(photoURL: String?) {
        let db = Firestore.firestore()
        
        // Extract time components from the tee time
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: teeTime)
        
        var updateData: [String: Any] = [
            "name": leagueName,
            "course": selectedCourse,
            "playDay": playDay.rawValue,
            "schedule": playFrequency,
            "teeTimeHour": timeComponents.hour ?? 9,
            "teeTimeMinute": timeComponents.minute ?? 0
        ]
        
        if let photoURL = photoURL {
            updateData["photoURL"] = photoURL
        }
        
        db.collection("leagues").document(league.id).updateData(updateData) { error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    alertMessage = "Error updating league: \(error.localizedDescription)"
                    showAlert = true
                } else {
                    alertMessage = "League updated successfully!"
                    showAlert = true
                    
                    // Update scheduled dates with new tee time
                    updateScheduledDatesWithNewTeeTime()
                }
            }
        }
    }
    
    private func updateScheduledDatesWithNewTeeTime() {
        let db = Firestore.firestore()
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: teeTime)
        let hour = timeComponents.hour ?? 9
        let minute = timeComponents.minute ?? 0
        
        // Get all future dates
        let today = Date()
        
        db.collection("leagues").document(league.id).collection("dates")
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: today))
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching dates to update tee time: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else { return }
                
                let batch = db.batch()
                
                for document in documents {
                    let dateRef = document.reference
                    let data = document.data()
                    
                    if let dateTimestamp = data["date"] as? Timestamp {
                        let date = dateTimestamp.dateValue()
                        let calendar = Calendar.current
                        
                        // Create a new date with the original date but new tee time
                        var components = calendar.dateComponents([.year, .month, .day], from: date)
                        components.hour = hour
                        components.minute = minute
                        components.second = 0
                        
                        if let newDate = calendar.date(from: components) {
                            batch.updateData(["date": Timestamp(date: newDate)], forDocument: dateRef)
                        }
                    }
                }
                
                // Commit the batch
                batch.commit { error in
                    if let error = error {
                        print("Error updating tee times: \(error.localizedDescription)")
                    } else {
                        print("Successfully updated tee times for future dates")
                    }
                }
            }
    }
    
    private func generateSchedule() {
        // Calculate dates based on frequency and day of week
        var scheduleDates: [Date] = []
        let calendar = Calendar.current
        
        // Start with current date
        var currentDate = Date()
        
        // Find next occurrence of play day
    }
}
