//
//  CurrentlyReadingManager.swift
//  Folio / Books
//

import Foundation
import Combine

struct ReadingProgressItem: Identifiable, Codable, Equatable {
    var id: String { path ?? title }
    let title: String
    let author: String
    let cover: String
    let path: String?
    var currentChapter: Int
    var currentSpread: Int?
    var lastReadDate: Date
    
    var spread: Int {
        currentSpread ?? 1
    }
}

class CurrentlyReadingManager: ObservableObject {
    static let shared = CurrentlyReadingManager()
    
    @Published var readingList: [Book] = []
    private var progressItems: [ReadingProgressItem] = []
    
    private let storageURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".books1_cache")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("currently_reading.json")
    }()
    
    init() {
        loadSaved()
    }
    
    func loadSaved() {
        if let data = try? Data(contentsOf: storageURL),
           let items = try? JSONDecoder().decode([ReadingProgressItem].self, from: data) {
            self.progressItems = items.sorted(by: { $0.lastReadDate > $1.lastReadDate })
            self.readingList = progressItems.map { item in
                Book(title: item.title, author: item.author, cover: item.cover, path: item.path)
            }
        }
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(progressItems) {
            try? data.write(to: storageURL)
        }
    }
    
    func getSavedProgress(for book: Book) -> (chapter: Int, spread: Int)? {
        let key = book.path ?? book.title
        if let item = progressItems.first(where: { ($0.path ?? $0.title) == key }) {
            return (item.currentChapter, item.spread)
        }
        return nil
    }
    
    func markAsReading(book: Book, chapterIndex: Int = 0, spreadIndex: Int = 1) {
        let key = book.path ?? book.title
        if let idx = progressItems.firstIndex(where: { ($0.path ?? $0.title) == key }) {
            progressItems[idx].currentChapter = chapterIndex
            progressItems[idx].currentSpread = spreadIndex
            progressItems[idx].lastReadDate = Date()
            let item = progressItems.remove(at: idx)
            progressItems.insert(item, at: 0)
        } else {
            let newItem = ReadingProgressItem(
                title: book.title,
                author: book.author,
                cover: book.cover,
                path: book.path,
                currentChapter: chapterIndex,
                currentSpread: spreadIndex,
                lastReadDate: Date()
            )
            progressItems.insert(newItem, at: 0)
        }
        self.readingList = progressItems.map { item in
            Book(title: item.title, author: item.author, cover: item.cover, path: item.path)
        }
        save()
    }
    
    func removeBook(book: Book) {
        let key = book.path ?? book.title
        progressItems.removeAll(where: { ($0.path ?? $0.title) == key })
        self.readingList = progressItems.map { item in
            Book(title: item.title, author: item.author, cover: item.cover, path: item.path)
        }
        save()
    }
}
