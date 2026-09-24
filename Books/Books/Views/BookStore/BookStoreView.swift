//
//  BookStoreView.swift
//  Books
//
//  Created by Matthew Andrea D'Alessio on 13/11/23.
//

import SwiftUI

struct BookStoreView: View {
    
    #if canImport(UIKit)
    init() {
        UINavigationBar.appearance().largeTitleTextAttributes = [.font : UIFont(name: "Georgia-Bold", size: 34)!]
        UINavigationBar.appearance().titleTextAttributes = [.font : UIFont(name: "Georgia-Bold", size: 19)!]
    }
    #endif
    
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedBook: Book?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Browse Sections Navigation Bar
                    NavigationLink(destination: BrowseSectionsView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "text.justifyleft")
                                .font(.system(size: 16))
                                .foregroundColor(.accentColor)
                            
                            Text("Browse Sections & Genres")
                                .font(.system(size: 15, weight: .medium))
                            
                            Spacer()
                            
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
                    
                    // Featured Books Carousel
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Featured Releases")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .padding(.horizontal, 28)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(BooksViewModel.books3) { book in
                                    Button(action: {
                                        selectedBook = book
                                    }) {
                                        NewBooksView(book3: book)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal, 28)
                    
                    // New & Trending Shelf
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("New & Trending")
                                    .font(.system(size: 22, weight: .bold, design: .serif))
                                Text("Recently released and buzz-y books.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 28)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 24) {
                                ForEach(BooksViewModel.books1) { book in
                                    Button(action: {
                                        selectedBook = book
                                    }) {
                                        BookCoverView(book: book, width: 135)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 8)
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal, 28)
                    
                    // Bestsellers & Top Charts Shelf
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Top Charts & Bestsellers")
                                    .font(.system(size: 22, weight: .bold, design: .serif))
                                Text("The most popular titles this week.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 28)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 24) {
                                ForEach(BooksViewModel.books2) { book in
                                    Button(action: {
                                        selectedBook = book
                                    }) {
                                        BookCoverView(book: book, width: 135)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Book Store")
        }
        .sheet(item: $selectedBook) { selectedBook in
            BookDetailView(book: selectedBook)
        }
    }
}
