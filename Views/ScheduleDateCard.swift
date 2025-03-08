//
//  ScheduleDateCard.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/8/25.
//


import SwiftUI
import FirebaseFirestore

struct ScheduleDateCard: View {
    let date: LeagueDate
    let league: EnhancedLeague
    @State private var showRSVPSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDay(date.date))
                        .font(.headline)
                    
                    Text(formatTime(date.date))
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(date.location)
                        .font(.subheadline)
                    
                    Text("\(date.confirmedCount) confirmed")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Divider()
            
            HStack {
                Spacer()
                
                Button(action: {
                    showRSVPSheet = true
                }) {
                    Text("RSVP")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .sheet(isPresented: $showRSVPSheet) {
            DateBasedRSVPView(leagueId: league.id)
        }
    }
    
    private func formatDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}