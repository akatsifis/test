// MARK: - Supporting Views for LeagueChat

import SwiftUI
import Firebase
import FirebaseFirestore

// Message Row View for displaying a single chat message
struct MessageRow: View {
    let message: LeagueMessage
    let isHost: Bool
    @State private var isCurrentUser = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Pinned indicator
            if message.isPinned {
                HStack {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                    Text("Pinned Message")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
            }
            
            // RSVP Message
            if message.isRSVP {
                RSVPMessageView(message: message)
            }
            // Score Submission
            else if message.isScoreSubmission {
                ScoreSubmissionView(message: message)
            }
            // Regular Message
            else {
                HStack(alignment: .top, spacing: 8) {
                    // Profile picture
                    if let profilePicUrl = message.profilePictureUrl, let url = URL(string: profilePicUrl) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text(String(message.username.prefix(1)).uppercased())
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(String(message.username.prefix(1)).uppercased())
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // Username with timestamp
                        HStack {
                            Text(message.username)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(isCurrentUser ? .blue : .gray)
                            
                            if isHost {
                                Text("Host")
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            Text(formatDate(message.timestamp))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        // Message content
                        Text(message.text)
                            .padding(10)
                            .background(isCurrentUser ? Color.blue.opacity(0.2) : Color(.systemGray6))
                            .cornerRadius(12)
                        
                        // Image if present
                        if let imageUrl = message.imageUrl, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: 200, maxHeight: 200)
                                        .cornerRadius(12)
                                } else if phase.error != nil {
                                    Image(systemName: "photo")
                                        .frame(width: 200, height: 200)
                                        .background(Color.gray.opacity(0.3))
                                        .cornerRadius(12)
                                } else {
                                    ProgressView()
                                        .frame(width: 200, height: 200)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            isCurrentUser = message.userId == Auth.auth().currentUser?.uid
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        // Highlight pinned messages
        .background(message.isPinned ? Color.orange.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        // If message is from today, just show time
        if Calendar.current.isDateInToday(date) {
            return formatter.string(from: date)
        }
        
        // Otherwise show date and time
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// View for displaying RSVP messages
struct RSVPMessageView: View {
    let message: LeagueMessage
    
    var body: some View {
        HStack {
            Image(systemName: rsvpIcon)
                .foregroundColor(rsvpColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(message.username) is \(rsvpText) for league night")
                    .font(.subheadline)
                
                if !message.text.isEmpty {
                    Text("Note: \"\(message.text)\"")
                        .font(.caption)
                        .italic()
                }
                
                Text(formatDate(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var rsvpText: String {
        guard let status = message.rsvpStatus else { return "undecided" }
        switch status {
        case "attending": return "attending"
        case "notAttending": return "not attending"
        case "maybe": return "possibly attending"
        default: return "undecided"
        }
    }
    
    private var rsvpIcon: String {
        guard let status = message.rsvpStatus else { return "questionmark.circle" }
        switch status {
        case "attending": return "checkmark.circle.fill"
        case "notAttending": return "xmark.circle.fill"
        case "maybe": return "questionmark.circle.fill"
        default: return "questionmark.circle"
        }
    }
    
    private var rsvpColor: Color {
        guard let status = message.rsvpStatus else { return .gray }
        switch status {
        case "attending": return .green
        case "notAttending": return .red
        case "maybe": return .orange
        default: return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// View for displaying score submission messages
struct ScoreSubmissionView: View {
    let message: LeagueMessage
    
    var body: some View {
        HStack {
            Image(systemName: "figure.golf")
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(message.username) submitted a score")
                    .font(.subheadline)
                
                if let score = message.submittedScore {
                    Text("Score: \(score)")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.caption)
                }
                
                Text(formatDate(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - RSVP View for League Events

struct RSVPView: View {
    let leagueId: String
    @State private var selectedStatus: RSVPStatus = .attending
    @State private var note: String = ""
    @State private var isSubmitting = false
    @State private var showingConfirmation = false
    @State private var selectedDate: LeagueChatDate?
    @State private var upcomingDates: [LeagueChatDate] = []
    @State private var isLoadingDates = true
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                // Date selection
                Section(header: Text("Select League Date")) {
                    if isLoadingDates {
                        ProgressView("Loading upcoming dates...")
                    } else if upcomingDates.isEmpty {
                        Text("No upcoming league dates found")
                            .foregroundColor(.gray)
                            .italic()
                    } else {
                        Picker("League Date", selection: $selectedDate) {
                            ForEach(upcomingDates) { date in
                                Text(formattedDate(date.date))
                                    .tag(date as LeagueChatDate?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        if let selectedDate = selectedDate {
                            HStack {
                                Text("Location:")
                                Spacer()
                                Text(selectedDate.location)
                                    .foregroundColor(.gray)
                            }
                            
                            HStack {
                                Text("Tee Time:")
                                Spacer()
                                Text(formattedTime(selectedDate.date))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                // Attendance selection
                if selectedDate != nil {
                    Section(header: Text("Will you attend?")) {
                        Picker("Attendance", selection: $selectedStatus) {
                            ForEach(RSVPStatus.allCases) { status in
                                HStack {
                                    Image(systemName: status.icon)
                                        .foregroundColor(status.color)
                                    Text(status.title)
                                }
                                .tag(status)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Players attending: \(selectedDate?.confirmedCount ?? 0)")
                                .font(.subheadline)
                        }
                    }
                    
                    Section(header: Text("Add a note (optional)")) {
                        TextEditor(text: $note)
                            .frame(height: 100)
                        
                        Text("\(note.count)/100 characters")
                            .font(.caption)
                            .foregroundColor(note.count > 100 ? .red : .gray)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    
                    // Submit button
                    Section {
                        Button(action: submitRSVP) {
                            if isSubmitting {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Submit RSVP")
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .listRowBackground(
                            Rectangle()
                                .fill(isSubmitting || note.count > 100 || selectedDate == nil ? Color.gray : selectedStatus.color)
                                .cornerRadius(8)
                        )
                        .disabled(isSubmitting || note.count > 100 || selectedDate == nil)
                    }
                }
            }
            .navigationTitle("RSVP for League")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showingConfirmation) {
                Alert(
                    title: Text("RSVP Submitted"),
                    message: Text("Your RSVP has been recorded for \(formattedDate(selectedDate?.date ?? Date()))"),
                    dismissButton: .default(Text("OK")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
            .onAppear(perform: loadUpcomingDates)
        }
    }
    
    private func loadUpcomingDates() {
        guard !leagueId.isEmpty else { return }
        
        isLoadingDates = true
        let db = Firestore.firestore()
        
        // Get current date at start of day
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        db.collection("leagues").document(leagueId).collection("dates")
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: today))
            .order(by: "date")
            .limit(to: 10)
            .getDocuments { snapshot, error in
                isLoadingDates = false
                
                if let error = error {
                    print("Error loading league dates: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("No upcoming league dates found")
                    return
                }
                
                self.upcomingDates = documents.compactMap { document -> LeagueChatDate? in
                    let data = document.data()
                    
                    guard let timestamp = data["date"] as? Timestamp,
                          let location = data["location"] as? String else {
                        return nil
                    }
                    
                    let confirmedCount = data["confirmedCount"] as? Int ?? 0
                    
                    return LeagueChatDate(
                        id: document.documentID,
                        date: timestamp.dateValue(),
                        location: location,
                        confirmedCount: confirmedCount
                    )
                }
                
                // Set the first date as selected by default
                if let firstDate = self.upcomingDates.first {
                    self.selectedDate = firstDate
                }
                
                // Get current user's RSVP for the selected date
                if let userId = Auth.auth().currentUser?.uid, let dateId = self.selectedDate?.id {
                    self.loadExistingRSVP(userId: userId, dateId: dateId)
                }
            }
    }
    
    private func loadExistingRSVP(userId: String, dateId: String) {
        let db = Firestore.firestore()
        
        db.collection("leagues").document(leagueId)
            .collection("dates").document(dateId)
            .collection("rsvps").document(userId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("Error loading RSVP: \(error.localizedDescription)")
                    return
                }
                
                if let data = snapshot?.data() {
                    if let statusStr = data["status"] as? String,
                       let status = RSVPStatus(rawValue: statusStr) {
                        self.selectedStatus = status
                    }
                    
                    if let noteText = data["note"] as? String {
                        self.note = noteText
                    }
                }
            }
    }
    
    private func submitRSVP() {
        guard !isSubmitting,
              note.count <= 100,
              let userId = Auth.auth().currentUser?.uid,
              let selectedDate = selectedDate else { return }
        
        isSubmitting = true
        
        // Get current user data
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                isSubmitting = false
                return
            }
            
            guard let data = snapshot?.data(),
                  let username = data["username"] as? String else {
                print("User data not found")
                isSubmitting = false
                return
            }
            
            // Create batch to update all related documents
            let batch = db.batch()
            
            // 1. Save RSVP to the date collection
            let rsvpData: [String: Any] = [
                "userId": userId,
                "username": username,
                "status": selectedStatus.rawValue,
                "note": note,
                "timestamp": FieldValue.serverTimestamp()
            ]
            
            let rsvpRef = db.collection("leagues").document(leagueId)
                .collection("dates").document(selectedDate.id)
                .collection("rsvps").document(userId)
            
            batch.setData(rsvpData, forDocument: rsvpRef)
            
            // 2. Update the counts on the date document
            let dateRef = db.collection("leagues").document(leagueId)
                .collection("dates").document(selectedDate.id)
            
            // Different field updates based on RSVP status
            switch selectedStatus {
            case .attending:
                batch.updateData([
                    "confirmedCount": FieldValue.increment(Int64(1))
                ], forDocument: dateRef)
            case .notAttending:
                batch.updateData([
                    "declinedCount": FieldValue.increment(Int64(1))
                ], forDocument: dateRef)
            case .maybe:
                batch.updateData([
                    "maybeCount": FieldValue.increment(Int64(1))
                ], forDocument: dateRef)
            }
            
            // 3. Create a message in the chat
            let messageData: [String: Any] = [
                "userId": userId,
                "username": username,
                "text": note,
                "timestamp": FieldValue.serverTimestamp(),
                "isRSVP": true,
                "rsvpStatus": selectedStatus.rawValue,
                "rsvpDate": Timestamp(date: selectedDate.date),
                "dateId": selectedDate.id
            ]
            
            let messageRef = db.collection("leagues").document(leagueId)
                .collection("messages").document()
                
            batch.setData(messageData, forDocument: messageRef)
            
            // Commit all updates
            batch.commit { error in
                isSubmitting = false
                
                if let error = error {
                    print("Error submitting RSVP: \(error.localizedDescription)")
                } else {
                    showingConfirmation = true
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
