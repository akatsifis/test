//
//  SectionHeader.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/8/25.
//


import SwiftUI

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.gray)
            .padding(.top, 10)
    }
}