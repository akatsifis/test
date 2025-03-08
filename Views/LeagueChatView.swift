import SwiftUI
import Firebase
import FirebaseFirestore

struct LeagueChatView: View {
    @State private var message = ""
    @State private var messages: [LeagueMessage] = []
    @State private var isLoading = true
    @State private var showingAttachmentOptions = false
    @State private var showingRSVPSheet = false
    
    let leagueId: String
    let leagueName: String
    
    var body: some View {
        VStack {
            // Header with RSVP button
            HStack {
                Text(leagueName)
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    showingRSVPSheet = true
                }) {
                    Text("RSVP")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            // Chat messages
            if isLoading {
                ProgressView("Loading messages...")
                    .padding()
            } else if messages.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                        .padding()
                    
                    Text("No messages yet")
                        .foregroundColor(.gray)
                    
                    Text("Be the first to send a message!")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            } else {
                ScrollViewReader { scrollView in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageRow(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .onChange(of: messages.count) { _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // Message input
            VStack(spacing: 0) {
                Divider()
                
                HStack {
                    Button(action: {
                        showingAttachmentOptions = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                    .padding(.leading, 10)
                    
                    TextField("Type a message...", text: $message)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(message.isEmpty ? .gray : .blue)
                    }
                    .disabled(message.isEmpty)
                    .padding(.trailing, 10)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 5)
                .background(Color(.systemBackground))
            }
        }
        .onAppear(perform: loadMessages)
        .sheet(isPresented: $showingAttachmentOptions) {
            AttachmentOptionsView { optionSelected in
                showingAttachmentOptions = false
                handleAttachmentOption(optionSelected)
            }
        }
        .sheet(isPresented: $showingRSVPSheet) {
            RSVPView(leagueId: leagueId)
        }
    }
    
    private func loadMessages() {
        guard !leagueId.isEmpty else { return }
        
        let db = Firestore.firestore()
        db.collection("leagues").document(leagueId).collection("messages")
            .order(by: "timestamp", descending: false)
            .limit(to: 100)
            .addSnapshotListener { snapshot, error in
                isLoading = false
                
                if let error = error {
                    print("Error loading messages: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.messages = documents.compactMap { document -> LeagueMessage? in
                    let data = document.data()
                    
                    guard let userId = data["userId"] as? String,
                          let username = data["username"] as? String,
                          let text = data["text"] as? String,
                          let timestamp = data["timestamp"] as? Timestamp else {
                        return nil
                    }
                    
                    let imageUrl = data["imageUrl"] as? String
                    let isRSVP = data["isRSVP"] as? Bool ?? false
                    let rsvpStatus = data["rsvpStatus"] as? String
                    
                    return LeagueMessage(
                        id: document.documentID,
                        userId: userId,
                        username: username,
                        text: text,
                        timestamp: timestamp.dateValue(),
                        imageUrl: imageUrl,
                        isRSVP: isRSVP,
                        rsvpStatus: rsvpStatus
                    )
                }
            }
    }
    
    private func sendMessage() {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !leagueId.isEmpty,
              let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        // Get current user data
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }
            
            guard let data = snapshot?.data(),
                  let username = data["username"] as? String else {
                print("User data not found")
                return
            }
            
            // Create message document
            let messageData: [String: Any] = [
                "userId": userId,
                "username": username,
                "text": message,
                "timestamp": FieldValue.serverTimestamp(),
                "isRSVP": false
            ]
            
            // Add to Firestore
            db.collection("leagues").document(leagueId).collection("messages")
                .addDocument(data: messageData) { error in
                    if let error = error {
                        print("Error sending message: \(error.localizedDescription)")
                    } else {
                        message = ""
                    }
                }
        }
    }
    
    private func handleAttachmentOption(_ option: AttachmentOption) {
        switch option {
        case .photo:
            // Handle photo attachment
            print("Photo attachment selected")
        case .location:
            // Handle location sharing
            print("Location sharing selected")
        case .poll:
            // Handle poll creation
            print("Poll creation selected")
        }
    }
}

// MARK: - Supporting Views and Models

struct MessageRow: View {
    let message: LeagueMessage
    @State private var isCurrentUser = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // RSVP Message
            if message.isRSVP {
                RSVPMessageView(message: message)
            }
            // Regular Message
            else {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.username)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                        
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
                        
                        Text(formatDate(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            isCurrentUser = message.userId == Auth.auth().currentUser?.uid
        }
        .padding(.horizontal, 4)
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

struct AttachmentOptionsView: View {
    let onOptionSelected: (AttachmentOption) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add to message")
                .font(.headline)
                .padding(.top)
            
            HStack(spacing: 30) {
                AttachmentButton(option: .photo, icon: "photo", color: .blue, onOptionSelected: onOptionSelected)
                AttachmentButton(option: .location, icon: "location.fill", color: .red, onOptionSelected: onOptionSelected)
                AttachmentButton(option: .poll, icon: "chart.bar", color: .purple, onOptionSelected: onOptionSelected)
            }
            .padding()
            
            Spacer()
        }
        .padding()
    }
}

struct AttachmentButton: View {
    let option: AttachmentOption
    let icon: String
    let color: Color
    let onOptionSelected: (AttachmentOption) -> Void
    
    var body: some View {
        Button(action: {
            onOptionSelected(option)
        }) {
            VStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundColor(color)
                    )
                
                Text(option.title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
    }
}

struct RSVPView: View {
    let leagueId: String
    @State private var selectedStatus: RSVPStatus = .attending
    @State private var note: String = ""
    @State private var isSubmitting = false
    @State private var showingConfirmation = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Will you attend the next league night?")) {
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
                }
                
                Section(header: Text("Add a note (optional)")) {
                    TextEditor(text: $note)
                        .frame(height: 100)
                    
                    Text("\(note.count)/100 characters")
                        .font(.caption)
                        .foregroundColor(note.count > 100 ? .red : .gray)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
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
                            .fill(isSubmitting || note.count > 100 ? Color.gray : selectedStatus.color)
                            .cornerRadius(8)
                    )
                    .disabled(isSubmitting || note.count > 100)
                }
            }
            .navigationTitle("RSVP for League Night")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showingConfirmation) {
                Alert(
                    title: Text("RSVP Submitted"),
                    message: Text("Your RSVP has been recorded."),
                    dismissButton: .default(Text("OK")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
    
    private func submitRSVP() {
        guard !isSubmitting, note.count <= 100, let userId = Auth.auth().currentUser?.uid else { return }
        
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
            
            // Save RSVP to league member collection
            let rsvpData: [String: Any] = [
                "status": selectedStatus.rawValue,
                "note": note,
                "timestamp": FieldValue.serverTimestamp()
            ]
            
            db.collection("leagues").document(leagueId)
                .collection("members").document(userId)
                .updateData(["rsvp": rsvpData]) { error in
                    if let error = error {
                        print("Error updating RSVP status: \(error.localizedDescription)")
                        isSubmitting = false
                        return
                    }
                    
                    // Also add RSVP message to chat
                    let messageData: [String: Any] = [
                        "userId": userId,
                        "username": username,
                        "text": note,
                        "timestamp": FieldValue.serverTimestamp(),
                        "isRSVP": true,
                        "rsvpStatus": selectedStatus.rawValue
                    ]
                    
                    db.collection("leagues").document(leagueId)
                        .collection("messages").addDocument(data: messageData) { error in
                            isSubmitting = false
                            
                            if let error = error {
                                print("Error sending RSVP message: \(error.localizedDescription)")
                            } else {
                                showingConfirmation = true
                            }
                        }
                }
        }
    }
}

// MARK: - Models

struct LeagueMessage: Identifiable {
    let id: String
    let userId: String
    let username: String
    let text: String
    let timestamp: Date
    let imageUrl: String?
    let isRSVP: Bool
    let rsvpStatus: String?
}

enum AttachmentOption {
    case photo, location, poll
    
    var title: String {
        switch self {
        case .photo: return "Photo"
        case .location: return "Location"
        case .poll: return "Poll"
        }
    }
}

enum RSVPStatus: String, CaseIterable, Identifiable {
    case attending
    case notAttending
    case maybe
    
    var id: String { self.rawValue }
    
    var title: String {
        switch self {
        case .attending: return "Yes, I'll be there"
        case .notAttending: return "No, I can't make it"
        case .maybe: return "Maybe"
        }
    }
    
    var icon: String {
        switch self {
        case .attending: return "checkmark.circle.fill"
        case .notAttending: return "xmark.circle.fill"
        case .maybe: return "questionmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .attending: return .green
        case .notAttending: return .red
        case .maybe: return .orange
        }
    }
}

struct LeagueChatView_Previews: PreviewProvider {
    static var previews: some View {
        LeagueChatView(leagueId: "preview-league-id", leagueName: "Tuesday Night League")
    }
}
