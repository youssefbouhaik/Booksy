//
//  WantToReadView.swift
//  Folio / Books
//

import SwiftUI

struct OpenLibraryDoc: Identifiable, Codable {
    var id: String { key }
    let key: String
    let title: String
    let author_name: [String]?
    let cover_i: Int?
    let first_publish_year: Int?
    
    var author: String {
        author_name?.first ?? "Unknown Author"
    }
    
    var coverURL: URL? {
        if let id = cover_i {
            return URL(string: "https://covers.openlibrary.org/b/id/\(id)-M.jpg")
        }
        return nil
    }
}

struct OpenLibraryResponse: Codable {
    let docs: [OpenLibraryDoc]
}

struct GutendexAuthor: Codable {
    let name: String
}

struct GutendexBook: Identifiable, Codable {
    let id: Int
    let title: String
    let authors: [GutendexAuthor]?
    let formats: [String: String]?
    let subjects: [String]?
    
    var author: String {
        guard let first = authors?.first?.name else { return "Unknown Author" }
        let parts = first.components(separatedBy: ", ")
        if parts.count == 2 {
            return "\(parts[1]) \(parts[0])"
        }
        return first
    }
    
    var coverURL: URL? {
        if let imgStr = formats?["image/jpeg"], let url = URL(string: imgStr) {
            return url
        }
        return nil
    }
}

struct GutendexResponse: Codable {
    let count: Int
    let results: [GutendexBook]
}

struct WantToReadItem: Identifiable, Codable {
    var id = UUID()
    let title: String
    let author: String
    let coverURL: String?
    let addedAt: Date
}

class WantToReadManager: ObservableObject {
    static let shared = WantToReadManager()
    
    @Published var savedItems: [WantToReadItem] = []
    @Published var searchResults: [OpenLibraryDoc] = []
    @Published var isSearching: Bool = false
    
    @Published var discoverBooks: [GutendexBook] = []
    @Published var isDiscoverLoading: Bool = false
    @Published var selectedTopic: String = "Popular"
    
    let topics = ["Popular", "Fiction", "Classics", "Philosophy", "Mystery", "Sci-Fi", "Adventure", "Poetry"]
    
    private let storageURL: URL = {
        let path = ("~/.books1_cache/want_to_read.json" as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path)
    }()
    
    init() {
        loadSaved()
        fetchDiscoverBooks()
    }
    
    func loadSaved() {
        if let data = try? Data(contentsOf: storageURL),
           let items = try? JSONDecoder().decode([WantToReadItem].self, from: data) {
            self.savedItems = items
        }
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(savedItems) {
            try? data.write(to: storageURL)
        }
    }
    
    func addItem(title: String, author: String, coverURL: String?) {
        if !savedItems.contains(where: { $0.title.lowercased() == title.lowercased() }) {
            let item = WantToReadItem(title: title, author: author, coverURL: coverURL, addedAt: Date())
            savedItems.insert(item, at: 0)
            save()
        }
    }
    
    func removeItem(id: UUID) {
        savedItems.removeAll { $0.id == id }
        save()
    }
    
    func fetchDiscoverBooks(topic: String = "Popular") {
        selectedTopic = topic
        isDiscoverLoading = true
        
        let randomPage = Int.random(in: 1...10)
        var urlString = "https://gutendex.com/books/?languages=en&page=\(randomPage)"
        if topic != "Popular" {
            let topicParam = topic.lowercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? topic.lowercased()
            urlString += "&topic=\(topicParam)"
        }
        
        guard let url = URL(string: urlString) else {
            isDiscoverLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isDiscoverLoading = false
                guard let data = data, error == nil else { return }
                if let resp = try? JSONDecoder().decode(GutendexResponse.self, from: data) {
                    let valid = resp.results.filter { $0.coverURL != nil }
                    self?.discoverBooks = valid.shuffled()
                }
            }
        }.resume()
    }
    
    func search(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://openlibrary.org/search.json?q=\(encoded)&limit=16") else {
            isSearching = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isSearching = false
                guard let data = data, error == nil else { return }
                if let resp = try? JSONDecoder().decode(OpenLibraryResponse.self, from: data) {
                    self?.searchResults = resp.docs
                }
            }
        }.resume()
    }
}

struct WantToReadView: View {
    @StateObject private var manager = WantToReadManager.shared
    @State private var searchQuery: String = ""
    
    let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 170), spacing: 24)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Want to Read")
                                .font(.system(size: 28, weight: .bold, design: .serif))
                            Text("Books you want to read next. Surf public domain books or search online catalogs.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search any book to add to Want to Read...", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .onSubmit {
                                manager.search(query: searchQuery)
                            }
                        
                        if manager.isSearching {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else if !searchQuery.isEmpty {
                            Button(action: {
                                searchQuery = ""
                                manager.searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .padding(.horizontal, 28)
                    
                    // Search Results (if searching)
                    if !manager.searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Online Search Results")
                                    .font(.system(size: 18, weight: .bold))
                                Spacer()
                                Button("Clear Results") {
                                    manager.searchResults = []
                                }
                                .font(.caption)
                            }
                            .padding(.horizontal, 28)
                            
                            LazyVGrid(columns: columns, spacing: 24) {
                                ForEach(manager.searchResults) { doc in
                                    let isSaved = manager.savedItems.contains(where: { $0.title.lowercased() == doc.title.lowercased() })
                                    VStack(alignment: .leading, spacing: 8) {
                                        ZStack {
                                            if let url = doc.coverURL {
                                                AsyncImage(url: url) { phase in
                                                    if let img = phase.image {
                                                        img.resizable().aspectRatio(2/3, contentMode: .fill)
                                                    } else {
                                                        Rectangle().fill(Color.secondary.opacity(0.15))
                                                    }
                                                }
                                            } else {
                                                Rectangle().fill(Color.secondary.opacity(0.15))
                                            }
                                        }
                                        .frame(width: 140, height: 210)
                                        .cornerRadius(8)
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                        
                                        Text(doc.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .lineLimit(2)
                                        
                                        Text(doc.author)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                        
                                        Button(action: {
                                            if !isSaved {
                                                manager.addItem(title: doc.title, author: doc.author, coverURL: doc.coverURL?.absoluteString)
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: isSaved ? "checkmark" : "plus.circle.fill")
                                                Text(isSaved ? "In Wishlist" : "Want to Read")
                                            }
                                            .font(.system(size: 11, weight: .semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(isSaved ? Color.secondary.opacity(0.15) : Color.accentColor.opacity(0.15))
                                            .foregroundColor(isSaved ? .secondary : .accentColor)
                                            .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(isSaved)
                                    }
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                        
                        Divider()
                            .padding(.horizontal, 28)
                    }
                    
                    // Surf & Discover Books Section
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "safari.fill")
                                    .foregroundColor(.accentColor)
                                Text("Surf & Discover")
                                    .font(.system(size: 20, weight: .bold))
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                manager.fetchDiscoverBooks(topic: manager.selectedTopic)
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Shuffle / New Books")
                                }
                                .font(.system(size: 11.5, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.primary.opacity(0.06)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 28)
                        
                        // Category Filter Chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(manager.topics, id: \.self) { topic in
                                    Button(action: {
                                        manager.fetchDiscoverBooks(topic: topic)
                                    }) {
                                        Text(topic)
                                            .font(.system(size: 12, weight: manager.selectedTopic == topic ? .semibold : .regular))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(manager.selectedTopic == topic ? Color.accentColor : Color.primary.opacity(0.06))
                                            )
                                            .foregroundColor(manager.selectedTopic == topic ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                        
                        if manager.isDiscoverLoading {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Surfing library catalogs...")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 32)
                        } else if !manager.discoverBooks.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 18) {
                                    ForEach(manager.discoverBooks) { book in
                                        let isSaved = manager.savedItems.contains(where: { $0.title.lowercased() == book.title.lowercased() })
                                        VStack(alignment: .leading, spacing: 8) {
                                            ZStack {
                                                if let url = book.coverURL {
                                                    AsyncImage(url: url) { phase in
                                                        if let img = phase.image {
                                                            img.resizable().aspectRatio(2/3, contentMode: .fill)
                                                        } else {
                                                            Rectangle().fill(Color.secondary.opacity(0.12))
                                                        }
                                                    }
                                                } else {
                                                    Rectangle().fill(Color.secondary.opacity(0.12))
                                                }
                                            }
                                            .frame(width: 125, height: 185)
                                            .cornerRadius(8)
                                            .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
                                            
                                            Text(book.title)
                                                .font(.system(size: 12, weight: .semibold))
                                                .lineLimit(2)
                                                .frame(width: 125, alignment: .leading)
                                            
                                            Text(book.author)
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .frame(width: 125, alignment: .leading)
                                            
                                            Button(action: {
                                                if !isSaved {
                                                    manager.addItem(title: book.title, author: book.author, coverURL: book.coverURL?.absoluteString)
                                                }
                                            }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: isSaved ? "checkmark" : "plus")
                                                    Text(isSaved ? "In Wishlist" : "Want to Read")
                                                }
                                                .font(.system(size: 10.5, weight: .semibold))
                                                .frame(width: 125)
                                                .padding(.vertical, 5)
                                                .background(isSaved ? Color.secondary.opacity(0.15) : Color.accentColor.opacity(0.15))
                                                .foregroundColor(isSaved ? .secondary : .accentColor)
                                                .cornerRadius(6)
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(isSaved)
                                        }
                                    }
                                }
                                .padding(.horizontal, 28)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal, 28)
                    
                    // Saved Wishlist
                    VStack(alignment: .leading, spacing: 14) {
                        Text("My Reading Wishlist (\(manager.savedItems.count))")
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, 28)
                        
                        if manager.savedItems.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bookmark")
                                    .font(.system(size: 36))
                                    .foregroundColor(.secondary)
                                Text("No books in your Want to Read list yet.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Surf through the public collection above or search to add books to your list.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVGrid(columns: columns, spacing: 24) {
                                ForEach(manager.savedItems) { item in
                                    VStack(alignment: .leading, spacing: 8) {
                                        ZStack(alignment: .topTrailing) {
                                            if let uStr = item.coverURL, let url = URL(string: uStr) {
                                                AsyncImage(url: url) { phase in
                                                    if let img = phase.image {
                                                        img.resizable().aspectRatio(2/3, contentMode: .fill)
                                                    } else {
                                                        Rectangle().fill(Color.secondary.opacity(0.15))
                                                    }
                                                }
                                            } else {
                                                Rectangle().fill(Color.secondary.opacity(0.15))
                                            }
                                            
                                            Button(action: {
                                                manager.removeItem(id: item.id)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.6)))
                                            }
                                            .buttonStyle(.plain)
                                            .padding(6)
                                        }
                                        .frame(width: 140, height: 210)
                                        .cornerRadius(8)
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                        
                                        Text(item.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .lineLimit(2)
                                        
                                        Text(item.author)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
}
