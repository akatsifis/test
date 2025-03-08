import SwiftUI
import Firebase
import FirebaseFirestore
import PhotosUI

struct LeagueEditView: View {
    let league: EnhancedLeague
    
    @State private var leagueName: String
    @State private var selectedCourse: String
    @State private var playDay: WeekDay
    @State private var playFrequency: String
    @State private var leaguePhoto: UIImage?
    @State private var showingPhotoPicker = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.presentationMode) var presentationMode
    
    init(league: EnhancedLeague) {
        self.league = league
        _leagueName = State(initialValue: league.name)
        _selectedCourse = State(initialValue: league.course)
        _playDay = State(initialValue: league.playDay)
        _playFrequency = State(initialValue: league.schedule)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // League Photo Section
                Section {
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
                        // Add more course options as needed
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
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingPhotoPicker) {
                LeaguePHPickerView(image: $leaguePhoto)
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
        
        var updateData: [String: Any] = [
            "name": leagueName,
            "course": selectedCourse,
            "playDay": playDay.rawValue,
            "schedule": playFrequency
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
                }
            }
        }
    }
}
