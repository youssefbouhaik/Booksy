//
//  BooksViewModel.swift
//  Books
//

import Foundation
import Combine

class BooksViewModel: ObservableObject {
    static let shared = BooksViewModel()
    
    @Published var books: [Book] = []
    @Published var hiddenKeys: Set<String> = []
    @Published var showHidden: Bool = false
    
    private let booksCacheURL: URL = {
        let path = ("~/.books1_cache/books.json" as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path)
    }()
    
    private let hiddenCacheURL: URL = {
        let path = ("~/.books1_cache/hidden_books.json" as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path)
    }()
    
    init() {
        loadHiddenKeys()
        loadBooks()
    }
    
    func loadHiddenKeys() {
        if let data = try? Data(contentsOf: hiddenCacheURL),
           let array = try? JSONDecoder().decode([String].self, from: data) {
            self.hiddenKeys = Set(array)
        } else {
            self.hiddenKeys = []
        }
    }
    
    func saveHiddenKeys() {
        let array = Array(hiddenKeys)
        if let data = try? JSONEncoder().encode(array) {
            try? data.write(to: hiddenCacheURL)
        }
    }
    
    func loadBooks() {
        var results: [Book] = []
        if let data = try? Data(contentsOf: booksCacheURL),
           let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for dict in jsonArray {
                guard let title = dict["title"] as? String,
                      let author = dict["author"] as? String,
                      let cover = dict["cover"] as? String,
                      let path = dict["path"] as? String else { continue }
                results.append(Book(title: title, author: author, cover: cover, path: path, categories: ["Library"]))
            }
        }
        self.books = results
    }
    
    func saveBooks() {
        let dictArray = books.compactMap { b -> [String: Any]? in
            guard let p = b.path else { return nil }
            return [
                "title": b.title,
                "author": b.author,
                "cover": b.cover,
                "path": p
            ]
        }
        if let data = try? JSONSerialization.data(withJSONObject: dictArray, options: [.prettyPrinted]) {
            try? data.write(to: booksCacheURL)
        }
    }
    
    var visibleBooks: [Book] {
        if showHidden {
            return books
        }
        return books.filter { !hiddenKeys.contains($0.path ?? $0.title) }
    }
    
    var hiddenBooksList: [Book] {
        books.filter { hiddenKeys.contains($0.path ?? $0.title) }
    }
    
    func registerOpenedBook(path: String) {
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()
        guard ext == "epub" || ext == "pdf" || ext == "mobi" else { return }
        
        if books.contains(where: { $0.path == path }) {
            if hiddenKeys.contains(path) {
                hiddenKeys.remove(path)
                saveHiddenKeys()
            }
            return
        }
        
        let title = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        let cover = ext == "pdf" ? "doc.text.fill" : "book.closed"
        let newBook = Book(title: title, author: "Local Library", cover: cover, path: path, categories: ["Library"])
        books.insert(newBook, at: 0)
        saveBooks()
    }
    
    func removeBook(book: Book) {
        let key = book.path ?? book.title
        books.removeAll(where: { ($0.path ?? $0.title) == key || ($0.path != nil && $0.path == book.path) })
        saveBooks()
        
        if hiddenKeys.contains(key) {
            hiddenKeys.remove(key)
            saveHiddenKeys()
        }
        if let p = book.path, hiddenKeys.contains(p) {
            hiddenKeys.remove(p)
            saveHiddenKeys()
        }
        
        CurrentlyReadingManager.shared.removeBook(book: book)
        FinishedBooksManager.shared.removeBook(book: book)
    }
    
    func hideBook(book: Book) {
        let key = book.path ?? book.title
        hiddenKeys.insert(key)
        if let p = book.path {
            hiddenKeys.insert(p)
        }
        saveHiddenKeys()
        CurrentlyReadingManager.shared.removeBook(book: book)
    }
    
    func unhideBook(book: Book) {
        let key = book.path ?? book.title
        hiddenKeys.remove(key)
        if let p = book.path {
            hiddenKeys.remove(p)
        }
        saveHiddenKeys()
    }
    
    func unhideAll() {
        hiddenKeys.removeAll()
        saveHiddenKeys()
    }
    
    // Static backward-compatible accessors
    static var userBooks: [Book] { shared.visibleBooks }
    static var allUserBooks: [Book] { shared.books }
    static var epubBooks: [Book] { shared.visibleBooks.filter { $0.isEPUB } }
    static var pdfBooks: [Book] { shared.visibleBooks.filter { $0.isPDF } }
    
    static func registerOpenedBook(path: String) {
        shared.registerOpenedBook(path: path)
    }
    static func removeBook(book: Book) {
        shared.removeBook(book: book)
    }
    static func hideBook(book: Book) {
        shared.hideBook(book: book)
    }
    static func unhideBook(book: Book) {
        shared.unhideBook(book: book)
    }
    static func unhideAll() {
        shared.unhideAll()
    }
    
    static var books1: [Book] { userBooks }
    static var books2: [Book] { Array(userBooks.prefix(20)) }
    static var books3: [Book] { Array(userBooks.dropFirst(20).prefix(5)) }
    static var books4: [Book] { Array(userBooks.dropFirst(25).prefix(25)) }
    static var books5: [Book] { Array(userBooks.dropFirst(50)) }
}
