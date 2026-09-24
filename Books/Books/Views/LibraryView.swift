//
//  LibraryView.swift
//  Folio / Books
//

import SwiftUI

enum LibraryFilter {
    case all
    case books
    case pdfs
}

struct LibraryView: View {
    @ObservedObject var booksVM = BooksViewModel.shared
    var filter: LibraryFilter = .all
    
    // Combine books for the user's personal collection
    var allLibraryBooks: [Book] {
        switch filter {
        case .all:
            return booksVM.visibleBooks
        case .books:
            return booksVM.visibleBooks.filter { $0.isEPUB }
        case .pdfs:
            return booksVM.visibleBooks.filter { $0.isPDF }
        }
    }
    
    var viewTitle: String {
        switch filter {
        case .all: return "All"
        case .books: return "Books"
        case .pdfs: return "PDFs"
        }
    }
    
    let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 28)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Bar (Apple Books clean typography)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewTitle)
                                .font(.system(size: 28, weight: .bold, design: .serif))
                            Text("\(allLibraryBooks.count) \(filter == .pdfs ? "PDF Documents" : "Books") in Collection")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !booksVM.hiddenKeys.isEmpty {
                            Menu {
                                Toggle("Show Hidden Books", isOn: $booksVM.showHidden)
                                Divider()
                                Button("Unhide All Books (\(booksVM.hiddenKeys.count))") {
                                    booksVM.unhideAll()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: booksVM.showHidden ? "eye" : "eye.slash")
                                        .font(.system(size: 12))
                                    Text(booksVM.showHidden ? "Showing Hidden" : "\(booksVM.hiddenKeys.count) Hidden")
                                        .font(.system(size: 12))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(12)
                            }
                            .menuStyle(.borderlessButton)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    
                    Divider()
                        .padding(.horizontal, 28)
                    
                    if allLibraryBooks.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: filter == .pdfs ? "doc.text.fill" : (filter == .books ? "book.fill" : "books.vertical.fill"))
                                .font(.system(size: 46))
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.top, 40)
                            
                            Text(filter == .pdfs ? "No PDFs in Library" : (filter == .books ? "No Books in Library" : "Your Library is Empty"))
                                .font(.system(size: 20, weight: .bold, design: .serif))
                            
                            Text(filter == .pdfs ? "Right-click any PDF in Finder and select Open With -> Booksy to read and catalog it." : "Right-click any .epub or .pdf in Finder and select Open With -> Booksy to read and catalog it.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 420)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        // Responsive Grid of Book Covers
                        LazyVGrid(columns: columns, spacing: 32) {
                            ForEach(allLibraryBooks) { book in
                                Button(action: {
                                    // Directly open book in independent reader window
                                    ReaderWindowManager.shared.openReader(for: book)
                                }) {
                                    BookCoverView(book: book, width: 140)
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                                .focusEffectDisabled()
                                .contextMenu {
                                    Button(action: {
                                        ReaderWindowManager.shared.openReader(for: book)
                                    }) {
                                        Label("Read Now", systemImage: "book")
                                    }
                                    
                                    Button(action: {
                                        FinishedBooksManager.shared.markAsFinished(book: book)
                                    }) {
                                        Label("Mark as Finished", systemImage: "checkmark.circle")
                                    }
                                    
                                    Divider()
                                    
                                    if booksVM.hiddenKeys.contains(book.path ?? book.title) {
                                        Button(action: {
                                            booksVM.unhideBook(book: book)
                                        }) {
                                            Label("Unhide Book", systemImage: "eye")
                                        }
                                    } else {
                                        Button(action: {
                                            booksVM.hideBook(book: book)
                                        }) {
                                            Label("Hide Book", systemImage: "eye.slash")
                                        }
                                    }
                                    
                                    Button(role: .destructive, action: {
                                        booksVM.removeBook(book: book)
                                    }) {
                                        Label("Remove from Collection", systemImage: "trash")
                                    }
                                    
                                    Divider()
                                    
                                    if let path = book.path {
                                        Button(action: {
                                            let task = Process()
                                            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                                            task.arguments = ["-R", path]
                                            try? task.run()
                                        }) {
                                            Label("Show in Finder", systemImage: "folder")
                                        }
                                        
                                        Button(action: {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(path, forType: .string)
                                        }) {
                                            Label("Copy File Path", systemImage: "doc.on.doc")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }
}
