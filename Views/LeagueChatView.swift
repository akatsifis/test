import SwiftUI
import Firebase
import FirebaseFirestore
import PhotosUI

struct LeagueChatView: View {
    @State private var message = ""
    @State private var messages: [LeagueMessage] = []
    @State private var isLoading = true
    @State private var showingAttachmentOptions = false
    @State private var showingRSVPSheet = false
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage? = nil
    @State private var isUploading = false
    @State private var scrollToBottom = false
    
    // For message moderation/deletion (host only)
    @State private var selectedMessage: LeagueMessage? = nil
    @State private var showingMessageOptions = false
    
    // Message listening
    @State private var isHost: Bool = false
    @State private var messagesListener: ListenerRegistration?
    
    let leagueId: String
    let leagueName: String
    
    var body: some View {
        VStack {
            // Chat header with RSVP button
            leagueChatHeader
            
            // Chat messages
            messagesView
            
            // Message input
            messageInputView
        }
        .onAppear {
            loadMessages()
            checkIfHost()
        }
        .onDisappear {
            // Clean up listener when view disappears
            messagesListener?.remove()
        }
        .sheet(isPresented: $showingRSVPSheet) {
            RSVPView(leagueId: leagueId)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
                .onDisappear {
                    if let image = selectedImage {
                        uploadImage(image)
                    }
                }
        }
        .actionSheet(isPresented: $showingAttachmentOptions) {
            ActionSheet(
                title: Text("Add to Message"),
                buttons: [
                    .default(Text("Photo")) { showingImagePicker = true },
                    .default(Text("Submit Score")) { /* Navigate to score submission */ },
                    .default(Text("Share Location")) { /* Share location feature */ },
                    .cancel()
                ]
            )
        }
        .actionSheet(isPresented: $showingMessageOptions, content: {
            guard let message = selectedMessage else {
                return ActionSheet(title: Text("Message Options"), buttons: [.cancel()])
            }
            
            return ActionSheet(
                title: Text("Message Options"),
                message: Text("Select an action for this message"),
                buttons: [
                    .destructive(Text("Delete Message")) {
                        deleteMessage(message)
                    },
                    isHost ? .default(Text("Pin Message")) { pinMessage(message) } : nil,
                    .cancel()
                ].compactMap { $0 }
            )
        })
    }
    
    // MARK: - UI Components
    
    private var leagueChatHeader: some View {
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
    }
    
    private var messagesView: some View {
        ScrollViewReader { scrollView in
            ScrollView {
                if isLoading {
                    ProgressView("Loading messages...")
                        .padding()
                } else if messages.isEmpty {
                    emptyMessagesView
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageRow(message: message, isHost: isHost)
                                .id(message.id)
                                .contextMenu {
                                    if isHost || message.userId == Auth.auth().currentUser?.uid {
                                        Button(action: {
                                            selectedMessage = message
                                            showingMessageOptions = true
                                        }) {
                                            Label("Message Options", systemImage: "ellipsis.circle")
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
            }
            .onChange(of: messages.count) { _ in
                if scrollToBottom {
                    withAnimation {
                        if let lastMessage = messages.last {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                    scrollToBottom = false
                }
            }
            .onAppear {
                // Scroll to bottom on initial load
                if !messages.isEmpty {
                    DispatchQueue.main.async {
                        withAnimation {
                            scrollView.scrollTo(messages.last!.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    private var emptyMessagesView: some View {
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
    }
    
    private var messageInputView: some View {
        VStack(spacing: 0) {
            Divider()
            
            // Input area
            HStack(alignment: .bottom) {
                Button(action: {
                    showingAttachmentOptions = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                .padding(.leading, 10)
                
                if isUploading {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Uploading...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                } else {
                    ZStack(alignment: .leading) {
                        if message.isEmpty {
                            Text("Type a message...")
                                .foregroundColor(.gray)
                                .padding(.leading, 15)
                                .padding(.top, 10)
                        }
                        
                        TextEditor(text: $message)
                            .padding(4)
                            .frame(minHeight: 40, maxHeight: 120)
                            .background(Color.clear)
                            .opacity(message.isEmpty ? 0.7 : 1)
                    }
                    .padding(5)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                }
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(message.isEmpty ? .gray : .blue)
                }
                .disabled(message.isEmpty)
                .padding(.trailing, 10)
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
    }
}


// MARK: - Data Functions for LeagueChatView

extension LeagueChatView {
    func loadMessages() {
        guard !leagueId.isEmpty else { return }
        
        isLoading = true
        
        // Cancel existing listener if any
        messagesListener?.remove()
        
        // Set up a new listener
        messagesListener = EnhancedLeagueService.shared.listenForMessages(leagueId: leagueId) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let fetchedMessages):
                    // Convert EnhancedLeagueMessage to LeagueMessage
                    self.messages = fetchedMessages.map { message in
                        return LeagueMessage(
                            id: message.id,
                            userId: message.userId,
                            username: message.username,
                            text: message.text,
                            timestamp: message.timestamp,
                            imageUrl: message.imageUrl,
                            isRSVP: message.isRsvp,
                            rsvpStatus: message.rsvpStatus,
                            isScoreSubmission: message.isScoreSubmission,
                            submittedScore: message.submittedScore,
                            profilePictureUrl: message.profilePictureUrl,
                            isPinned: false  // Default to false, update if needed
                        )
                    }
                    
                    // Sort messages with pinned ones at the top, then by timestamp
                    self.messages.sort { (msg1, msg2) -> Bool in
                        if msg1.isPinned && !msg2.isPinned {
                            return true
                        } else if !msg1.isPinned && msg2.isPinned {
                            return false
                        } else {
                            return msg1.timestamp < msg2.timestamp
                        }
                    }
                    
                case .failure(let error):
                    print("Error loading messages: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func checkIfHost() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("leagues").document(leagueId).getDocument { snapshot, error in
            if let error = error {
                print("Error checking host status: \(error.localizedDescription)")
                return
            }
            
            if let data = snapshot?.data(), let hostId = data["hostUserId"] as? String {
                self.isHost = (hostId == currentUserId)
            }
        }
    }
    
    func sendMessage() {
        let messageText = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty,
              !leagueId.isEmpty,
              let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        // Save the message text and clear the input field
        let currentMessage = messageText
        message = ""
        scrollToBottom = true
        
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
            
            let profilePictureUrl = data["profilePicture"] as? String
            
            // Create an EnhancedLeagueMessage
            let leagueMessage = EnhancedLeagueMessage(
                id: UUID().uuidString,
                userId: userId,
                username: username,
                text: currentMessage,
                timestamp: Date(),
                imageUrl: nil,
                isRsvp: false,
                rsvpStatus: nil,
                isScoreSubmission: false,
                submittedScore: nil,
                profilePictureUrl: profilePictureUrl
            )
            
            // Post the message using the service
            EnhancedLeagueService.shared.postLeagueMessage(leagueId: leagueId, message: leagueMessage) { result in
                switch result {
                case .success:
                    print("Message sent successfully")
                case .failure(let error):
                    print("Error sending message: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func uploadImage(_ image: UIImage) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isUploading = true
        
        // Upload image
        ImageUploadService.shared.uploadImage(
            image: image,
            path: "league_messages/\(leagueId)",
            compressionQuality: 0.7
        ) { result in
            DispatchQueue.main.async {
                self.isUploading = false
                self.selectedImage = nil
                
                switch result {
                case .success(let imageUrl):
                    // Now send a message with the image URL
                    self.sendMessageWithImage(imageUrl)
                    
                case .failure(let error):
                    print("Error uploading image: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func sendMessageWithImage(_ imageUrl: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snapshot, error in
            guard let data = snapshot?.data(),
                  let username = data["username"] as? String else {
                return
            }
            
            let profilePictureUrl = data["profilePicture"] as? String
            let messageText = self.message.isEmpty ? "Shared an image" : self.message
            
            // Create the message with image URL
            let leagueMessage = EnhancedLeagueMessage(
                id: UUID().uuidString,
                userId: userId,
                username: username,
                text: messageText,
                timestamp: Date(),
                imageUrl: imageUrl,
                isRsvp: false,
                rsvpStatus: nil,
                isScoreSubmission: false,
                submittedScore: nil,
                profilePictureUrl: profilePictureUrl
            )
            
            // Post the message
            EnhancedLeagueService.shared.postLeagueMessage(leagueId: self.leagueId, message: leagueMessage) { _ in
                DispatchQueue.main.async {
                    self.message = ""
                    self.scrollToBottom = true
                }
            }
        }
    }
    
    func deleteMessage(_ message: LeagueMessage) {
        guard isHost || message.userId == Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("leagues").document(leagueId)
            .collection("messages").document(message.id)
            .delete { error in
                if let error = error {
                    print("Error deleting message: \(error.localizedDescription)")
                }
            }
    }
    
    func pinMessage(_ message: LeagueMessage) {
        guard isHost else { return }
        
        let db = Firestore.firestore()
        db.collection("leagues").document(leagueId)
            .collection("messages").document(message.id)
            .updateData(["isPinned": true]) { error in
                if let error = error {
                    print("Error pinning message: \(error.localizedDescription)")
                }
            }
    }
}
