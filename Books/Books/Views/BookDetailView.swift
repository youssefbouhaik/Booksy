//
//  BookDetailView.swift
//  Books
//

import SwiftUI

struct BookDetailView: View {
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var book: Book
    @State private var showEmbeddedReader: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Bar
                HStack {
                    Text("Book Info")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 12)
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Two Column Layout
                        HStack(alignment: .top, spacing: 32) {
                            // Left: Book cover with authentic 2:3 ratio and shadows
                            BookCoverView(book: book, width: 170, showTitle: false)
                                .padding(.leading, 8)
                            
                            // Right: Title, Author, Format info & Real Actions
                            VStack(alignment: .leading, spacing: 14) {
                                Text(book.title)
                                    .font(.system(size: 24, weight: .bold, design: .serif))
                                    .foregroundColor(.primary)
                                
                                Text(book.author)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                // File format & status pill
                                HStack(spacing: 8) {
                                    Text("EPUB")
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.secondary.opacity(0.15))
                                        .cornerRadius(6)
                                    
                                    Text("Downloaded")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                
                                // Real Action Buttons
                                HStack(spacing: 10) {
                                    Button(action: {
                                        ReaderWindowManager.shared.openReader(for: book)
                                        dismiss()
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "book.fill")
                                            Text("READ")
                                                .font(.system(size: 13, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 9)
                                        .background(Color.accentColor)
                                        .cornerRadius(20)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: {
                                        ReaderWindowManager.shared.openReader(for: book)
                                        dismiss()
                                    }) {
                                        HStack(spacing: 5) {
                                            Image(systemName: "headphones")
                                            Text("Listen")
                                                .font(.system(size: 12, weight: .semibold))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: {
                                        FinishedBooksManager.shared.markAsFinished(book: book)
                                    }) {
                                        HStack(spacing: 5) {
                                            Image(systemName: "checkmark.circle")
                                            Text("Mark Finished")
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: {
                                        WantToReadManager.shared.addItem(title: book.title, author: book.author, coverURL: nil)
                                    }) {
                                        HStack(spacing: 5) {
                                            Image(systemName: "bookmark")
                                            Text("Want to Read")
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if let path = book.path {
                                        Button(action: {
                                            let task = Process()
                                            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                                            task.arguments = ["-R", path]
                                            try? task.run()
                                        }) {
                                            HStack(spacing: 5) {
                                                Image(systemName: "folder")
                                                Text("Finder")
                                                    .font(.system(size: 12, weight: .medium))
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color(nsColor: .controlBackgroundColor))
                                            .cornerRadius(20)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    Button(action: {
                                        let key = book.path ?? book.title
                                        if BooksViewModel.shared.hiddenKeys.contains(key) {
                                            BooksViewModel.shared.unhideBook(book: book)
                                        } else {
                                            BooksViewModel.shared.hideBook(book: book)
                                        }
                                        dismiss()
                                    }) {
                                        HStack(spacing: 5) {
                                            let isHidden = BooksViewModel.shared.hiddenKeys.contains(book.path ?? book.title)
                                            Image(systemName: isHidden ? "eye" : "eye.slash")
                                            Text(isHidden ? "Unhide" : "Hide")
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: {
                                        BooksViewModel.shared.removeBook(book: book)
                                        dismiss()
                                    }) {
                                        HStack(spacing: 5) {
                                            Image(systemName: "trash")
                                            Text("Remove")
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.top, 6)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        
                        Divider()
                            .padding(.horizontal, 24)
                        
                        // Book Details & Location
                        VStack(alignment: .leading, spacing: 10) {
                            Text("File Details")
                                .font(.system(size: 16, weight: .bold))
                            
                            if let path = book.path {
                                Text(path)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                }
            }
            .frame(minWidth: 580, idealWidth: 640, minHeight: 420, idealHeight: 460)
        }
    }
}
