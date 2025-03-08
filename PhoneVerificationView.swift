import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PhoneVerificationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var verificationId: String? = nil
    @State private var isCodeSent = false
    @State private var isVerifying = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            if !isCodeSent {
                // Phone Number Entry
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter your phone number")
                        .font(.headline)
                    
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Text("We'll send a verification code to this number")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Button(action: sendVerificationCode) {
                    if isVerifying {
                        ProgressView()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    } else {
                        Text("Send Code")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(phoneNumber.isEmpty || isVerifying)
            } else {
                // Verification Code Entry
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter verification code")
                        .font(.headline)
                    
                    TextField("Code", text: $verificationCode)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Text("Enter the 6-digit code sent to \(phoneNumber)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Button(action: verifyCode) {
                    if isVerifying {
                        ProgressView()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    } else {
                        Text("Verify")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(verificationCode.count < 6 || isVerifying)
                
                Button(action: {
                    isCodeSent = false
                    verificationCode = ""
                }) {
                    Text("Change Phone Number")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .navigationTitle("Phone Verification")
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func sendVerificationCode() {
        guard !phoneNumber.isEmpty else { return }
        
        isVerifying = true
        
        // Format phone number if needed
        let formattedNumber = formatPhoneNumber(phoneNumber)
        
        // Call Auth.auth().verifyPhoneNumber directly
        PhoneAuthProvider.provider().verifyPhoneNumber(formattedNumber, uiDelegate: nil) { verificationID, error in
            isVerifying = false
            
            if let error = error {
                alertTitle = "Error"
                alertMessage = "Failed to send verification code: \(error.localizedDescription)"
                showAlert = true
                return
            }
            
            if let verificationID = verificationID {
                self.verificationId = verificationID
                isCodeSent = true
            }
        }
    }
    
    private func verifyCode() {
        guard let verificationId = verificationId, !verificationCode.isEmpty else { return }
        
        isVerifying = true
        
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationId,
            verificationCode: verificationCode
        )
        
        Auth.auth().signIn(with: credential) { authResult, error in
            isVerifying = false
            
            if let error = error {
                alertTitle = "Error"
                alertMessage = "Failed to verify code: \(error.localizedDescription)"
                showAlert = true
                return
            }
            
            // Update the auth manager
            if let user = authResult?.user {
                // Just update Firestore directly instead of using AuthManager
                let db = Firestore.firestore()
                if let userId = Auth.auth().currentUser?.uid {
                    db.collection("users").document(userId).updateData([
                        "phoneNumber": user.phoneNumber ?? phoneNumber
                    ]) { error in
                        if let error = error {
                            alertTitle = "Warning"
                            alertMessage = "Authentication successful but failed to update profile: \(error.localizedDescription)"
                            showAlert = true
                        } else {
                            // Update successful - dismiss
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }
    }
    
    private func formatPhoneNumber(_ number: String) -> String {
        // Simple formatting - assumes US number
        if !number.hasPrefix("+") {
            if number.hasPrefix("1") {
                return "+\(number)"
            } else {
                return "+1\(number)"
            }
        }
        return number
    }
}

struct PhoneVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        PhoneVerificationView()
            .environmentObject(AuthenticationManager())
    }
}
