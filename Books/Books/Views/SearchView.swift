//
//  SearchView.swift
//  Books
//
//  Created by Matthew Andrea D'Alessio on 13/11/23.
//

import SwiftUI

struct SearchView: View {
    
    #if canImport(UIKit)
    init() {
            UINavigationBar.appearance().largeTitleTextAttributes = [.font : UIFont(name: "Georgia-Bold", size: 34)!]
            UINavigationBar.appearance().titleTextAttributes = [.font : UIFont(name: "Georgia-Bold", size: 19)!]
        }
#endif
    
    @Environment(\.colorScheme) var colorScheme
    
    @State private var searchText = ""
    @State private var selectedBook: Book?
    
    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return []
        } else {
            return BooksViewModel.userBooks.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) || $0.author.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 64, weight: .light))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Text("Search Your Library")
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredBooks, id: \.id) { book in
                            Button(action: {
                                if book.path != nil {
                                    ReaderWindowManager.shared.openReader(for: book)
                                } else {
                                    selectedBook = book
                                }
                            }) {
                                HStack {
                                    BookCoverView(book: book, width: 44, showTitle: false)
                                        .frame(width: 44, height: 66)
                                        .cornerRadius(3)
                                        .shadow(color: Color.black.opacity(0.15), radius: 3, x: 1, y: 2)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(book.title)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .lineLimit(2)

                                        Text(book.author)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    .padding(.leading, 10)

                                    Spacer()

                                    Text(book.isPDF ? "PDF" : "READ")
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 14)
                                        .background(colorScheme == .dark ? Color.white.opacity(0.2) : Color.gray.opacity(0.15))
                                        .cornerRadius(20)
                                }
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .focusEffectDisabled()
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Search")
        }
        .searchable(text: $searchText, prompt: "Search Books & PDFs")
            .sheet(item: $selectedBook) { book in
                BookDetailView(book: book)
            }
        }
    
}

// #Preview {
//     SearchView()
// }
