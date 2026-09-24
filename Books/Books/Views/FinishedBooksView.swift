//
//  FinishedBooksView.swift
//  Folio / Books
//

import SwiftUI

struct FinishedBookItem: Identifiable, Codable {
    var id: UUID = UUID()
    let title: String
    let author: String
    let cover: String
    let path: String?
    let finishedDate: String
    
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        if let d = formatter.date(from: finishedDate) {
            let out = DateFormatter()
            out.dateFormat = "MMM d"
            return out.string(from: d)
        }
        return "Recent"
    }
}

class FinishedBooksManager: ObservableObject {
    static let shared = FinishedBooksManager()
    
    @Published var finishedBooks: [FinishedBookItem] = []
    
    private let storageURL: URL = {
        let path = ("~/.books1_cache/finished_books.json" as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path)
    }()
    
    init() {
        loadSaved()
    }
    
    func loadSaved() {
        if let data = try? Data(contentsOf: storageURL),
           let items = try? JSONDecoder().decode([FinishedBookItem].self, from: data) {
            self.finishedBooks = items
        }
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(finishedBooks) {
            try? data.write(to: storageURL)
        }
    }
    
    func markAsFinished(book: Book) {
        if !finishedBooks.contains(where: { $0.title.lowercased() == book.title.lowercased() }) {
            let formatter = ISO8601DateFormatter()
            let nowStr = formatter.string(from: Date())
            let item = FinishedBookItem(title: book.title, author: book.author, cover: book.cover, path: book.path, finishedDate: nowStr)
            finishedBooks.insert(item, at: 0)
            save()
            CurrentlyReadingManager.shared.removeBook(book: book)
        }
    }
    
    func removeBook(book: Book) {
        let key = book.path ?? book.title
        finishedBooks.removeAll(where: { ($0.path ?? $0.title) == key || $0.title.lowercased() == book.title.lowercased() })
        save()
    }
}

struct FinishedBooksView: View {
    @StateObject private var manager = FinishedBooksManager.shared
    @State private var selectedBook: Book?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Top Bar Header
                    HStack {
                        Text("Finished")
                            .font(.system(size: 38, weight: .bold, design: .serif))
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 36)
                    .padding(.top, 24)
                    
                    // Vertical Timeline List
                    if manager.finishedBooks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal")
                                .font(.system(size: 44))
                                .foregroundColor(.secondary)
                            Text("No finished books yet.")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Books you mark as finished will appear along your reading timeline here.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(manager.finishedBooks.enumerated()), id: \.element.title) { index, item in
                                let book = Book(title: item.title, author: item.author, cover: item.cover, path: item.path)
                                
                                HStack(alignment: .center, spacing: 20) {
                                    // Timeline Column (Date + Center Node Line)
                                    HStack(spacing: 12) {
                                        Text(item.formattedDate)
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(.secondary)
                                            .frame(width: 62, alignment: .trailing)
                                        
                                        // Continuous Vertical Track with Dead-Center Dot
                                        ZStack(alignment: .center) {
                                            Rectangle()
                                                .fill(Color(nsColor: .systemGray))
                                                .frame(width: 1.5)
                                            
                                            Circle()
                                                .fill(Color(nsColor: .systemGray))
                                                .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
                                                .frame(width: 9, height: 8)
                                        }
                                        .frame(width: 12)
                                    }
                                    
                                    // Book Content Card
                                    HStack(alignment: .center, spacing: 20) {
                                        BookCoverView(book: book, width: 110, showTitle: false)
                                            .onTapGesture {
                                                ReaderWindowManager.shared.openReader(for: book)
                                            }
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(item.title)
                                                .font(.system(size: 19, weight: .bold, design: .serif))
                                                .lineLimit(2)
                                                .onTapGesture {
                                                    ReaderWindowManager.shared.openReader(for: book)
                                                }
                                            
                                            Text(item.author)
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                            
                                            Menu {
                                                Button(action: {
                                                    ReaderWindowManager.shared.openReader(for: book)
                                                }) {
                                                    Label("Read Again", systemImage: "book")
                                                }
                                                
                                                Button(action: {
                                                    manager.removeBook(book: book)
                                                }) {
                                                    Label("Remove from Finished", systemImage: "xmark.circle")
                                                }
                                                
                                                Divider()
                                                
                                                Button(action: {
                                                    BooksViewModel.shared.hideBook(book: book)
                                                }) {
                                                    Label("Hide Book", systemImage: "eye.slash")
                                                }
                                                
                                                Button(role: .destructive, action: {
                                                    BooksViewModel.shared.removeBook(book: book)
                                                }) {
                                                    Label("Remove from Collection", systemImage: "trash")
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.secondary)
                                                    .padding(.top, 4)
                                            }
                                            .menuStyle(.borderlessButton)
                                            .focusable(false)
                                            .focusEffectDisabled()
                                        }
                                        .padding(.top, 4)
                                        
                                        Spacer()
                                    }
                                    .contextMenu {
                                        Button(action: {
                                            ReaderWindowManager.shared.openReader(for: book)
                                        }) {
                                            Label("Read Again", systemImage: "book")
                                        }
                                        
                                        Button(action: {
                                            manager.removeBook(book: book)
                                        }) {
                                            Label("Remove from Finished", systemImage: "xmark.circle")
                                        }
                                        
                                        Divider()
                                        
                                        Button(action: {
                                            BooksViewModel.shared.hideBook(book: book)
                                        }) {
                                            Label("Hide Book", systemImage: "eye.slash")
                                        }
                                        
                                        Button(role: .destructive, action: {
                                            BooksViewModel.shared.removeBook(book: book)
                                        }) {
                                            Label("Remove from Collection", systemImage: "trash")
                                        }
                                    }
                                }
                                .padding(.bottom, 36)
                            }
                        }
                        .padding(.horizontal, 36)
                        .padding(.top, 12)
                    }
                }
            }
        }
    }
}
