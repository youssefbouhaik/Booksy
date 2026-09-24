//
//  ReaderModels.swift
//  Folio / Books
//
//  Shared data models and persistence stores for Reader (TOC, Bookmarks, Notes, PDF Outlines, Script Resolution)
//

import Foundation
import PDFKit

// MARK: - PDF Outline
struct PDFOutlineNode: Identifiable {
    let id = UUID()
    let title: String
    let pageIndex: Int
}

func extractPDFOutline(from doc: PDFDocument) -> [PDFOutlineNode] {
    var nodes: [PDFOutlineNode] = []
    guard let root = doc.outlineRoot else { return [] }
    
    func traverse(outline: PDFOutline) {
        for i in 0..<outline.numberOfChildren {
            if let child = outline.child(at: i) {
                if let label = child.label, let dest = child.destination, let page = dest.page {
                    let pIndex = doc.index(for: page)
                    nodes.append(PDFOutlineNode(title: label, pageIndex: pIndex))
                }
                traverse(outline: child)
            }
        }
    }
    traverse(outline: root)
    return nodes
}

// MARK: - Table of Contents & Metadata
struct BookTOCEntry: Identifiable, Codable {
    var id: String { "\(chapterIndex)_\(page)_\(title)" }
    let title: String
    let chapterIndex: Int
    let page: Int
    let level: Int
}

struct BookMetadataResponse: Codable {
    let totalPages: Int
    let chapters: [BookTOCEntry]
    let spinePages: [Int]
}

// MARK: - Bookmarks
struct BookmarkItem: Identifiable, Codable {
    let id: UUID
    let chapterIndex: Int
    let spreadIndex: Int
    let chapterTitle: String
    let pageNumber: Int
    let date: Date
}

class BookmarksStorage {
    static let shared = BookmarksStorage()
    private let fileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".books1_cache")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("bookmarks.json")
    }()
    
    func loadBookmarks(for bookKey: String) -> [BookmarkItem] {
        guard let data = try? Data(contentsOf: fileURL),
              let dict = try? JSONDecoder().decode([String: [BookmarkItem]].self, from: data) else {
            return []
        }
        return dict[bookKey] ?? []
    }
    
    func saveBookmarks(_ items: [BookmarkItem], for bookKey: String) {
        var dict: [String: [BookmarkItem]] = [:]
        if let data = try? Data(contentsOf: fileURL),
           let existing = try? JSONDecoder().decode([String: [BookmarkItem]].self, from: data) {
            dict = existing
        }
        dict[bookKey] = items
        if let encoded = try? JSONEncoder().encode(dict) {
            try? encoded.write(to: fileURL)
        }
    }
}

// MARK: - Notes & Annotations
struct NoteItem: Identifiable, Codable {
    let id: UUID
    var text: String
    var note: String
    var colorHex: String
    let chapterIndex: Int
    let spreadIndex: Int
    let pageNumber: Int
    let chapterTitle: String
    let date: Date
}

class NotesStorage {
    static let shared = NotesStorage()
    private let fileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".books1_cache")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("notes.json")
    }()
    
    func loadNotes(for bookKey: String) -> [NoteItem] {
        guard let data = try? Data(contentsOf: fileURL),
              let dict = try? JSONDecoder().decode([String: [NoteItem]].self, from: data) else {
            return []
        }
        return dict[bookKey] ?? []
    }
    
    func saveNotes(_ items: [NoteItem], for bookKey: String) {
        var dict: [String: [NoteItem]] = [:]
        if let data = try? Data(contentsOf: fileURL),
           let existing = try? JSONDecoder().decode([String: [NoteItem]].self, from: data) {
            dict = existing
        }
        dict[bookKey] = items
        if let encoded = try? JSONEncoder().encode(dict) {
            try? encoded.write(to: fileURL)
        }
    }
}

// MARK: - Script Resolution & Helper Environment
struct ScriptResolver {
    static var pythonPath: String {
        let home = NSHomeDirectory()
        let candidates = [
            Bundle.main.resourcePath.map { "\($0)/venv/bin/python3" },
            "\(home)/aperture-epub-reader/.venv/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3"
        ].compactMap { $0 }
        
        for cand in candidates {
            if FileManager.default.fileExists(atPath: cand) {
                return cand
            }
        }
        return "/usr/bin/python3"
    }
    
    static func scriptPath(named name: String) -> String {
        if let res = Bundle.main.resourcePath {
            let bundleScript = "\(res)/scripts/\(name)"
            if FileManager.default.fileExists(atPath: bundleScript) {
                return bundleScript
            }
        }
        let home = NSHomeDirectory()
        let localScript = "\(home)/aperture-epub-reader/\(name)"
        if FileManager.default.fileExists(atPath: localScript) {
            return localScript
        }
        return name
    }
}
