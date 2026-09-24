//
//  NewBooksView.swift
//  Books
//
//  Created by Matthew Andrea D'Alessio on 19/11/23.
//

import SwiftUI

struct NewBooksView: View {
    var book3: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FEATURED NEW")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.accentColor)
                
                Text(book3.title)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .lineLimit(1)
                
                Text(book3.author)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 280, alignment: .leading)
            
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 280, height: 210)
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
                
                BookCoverView(book: book3, width: 110, showTitle: false)
            }
        }
        .frame(width: 280)
    }
}
