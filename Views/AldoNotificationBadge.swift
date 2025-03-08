// AldoNotificationBadge.swift
import SwiftUI

struct AldoNotificationBadge: View {
    let count: Int
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
            
            if count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.system(size: 12))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.red)
                    .clipShape(Capsule())
                    .offset(x: 12, y: -12)
                    .animation(.default)
            }
        }
    }
}
