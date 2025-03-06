//
//  PhoneVerificationView.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/5/25.
//

import SwiftUI
import Firebase

struct PhoneVerificationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var phoneNumber: String = ""
    @State private var verificationCode: String = ""
    @State private var isVerificationSent = false
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Phone Verification")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 20)
            
            if !isVerificationSent {
                // Phone number input
                TextField("Phone Number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                Button(action: sendVerificationCode) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Send Verification Code")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                }
                .background(isLoading ? Color.gray : Color.blue)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(isLoading || phoneNumber.isEmpty)
            } else {
                // Verification code input
                TextField("Verification Code", text: $verificationCode)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                Button(action: verifyCode) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Verify Code")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                }
                .background(isLoading ? Color.gray : Color.green)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(isLoading || verificationCode.isEmpty)
                
                Button(action: {
                    isVerificationSent = false
                    errorMessage = nil
                }) {
                    Text("Change Phone Number")
                        .foregroundColor(.blue)
                        .padding(.top)
                }
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func sendVerificationCode() {
        isLoading = true
        errorMessage = nil
        
        // Format phone number to E.164 standard if needed
        let formattedNumber = formatPhoneNumber(phoneNumber)
        
        $authManager.sendVerificationCode(to: formattedNumber) { success, error in
            isLoading = false
            
            if success {
                isVerificationSent = true
            } else {
                errorMessage = error ?? "Failed to send verification code. Please try again."
            }
        }
    }
    
    private func verifyCode() {
        isLoading = true
        errorMessage = nil
        
        authManager.verifyCode(code: verificationCode) { success, error in
            isLoading = false
            
            if success {
                presentationMode.wrappedValue.dismiss()
            } else {
                errorMessage = error ?? "Invalid verification code. Please try again."
            }
        }
    }
    
    private func formatPhoneNumber(_ number: String) -> String {
        // Simple formatting - ensure it starts with "+" if not already
        if number.hasPrefix("+") {
            return number
        } else if number.hasPrefix("1") {
            return "+\(number)"
        } else {
            return "+1\(number)" // Default to US code
        }
    }
}

struct PhoneVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        PhoneVerificationView()
            .environmentObject(AuthenticationManager())
    }
}
