//
//  Book.swift
//  Books
//

import Foundation

struct Book: Identifiable, Codable {
    var id = UUID()
    var title: String
    var author: String
    var cover: String
    var path: String?
    var categories: [String] = ["Library"]
    
    var isPDF: Bool {
        guard let p = path else { return false }
        return p.lowercased().hasSuffix(".pdf")
    }
    
    var isEPUB: Bool {
        guard let p = path else { return false }
        let ext = (p as NSString).pathExtension.lowercased()
        return ext == "epub" || ext == "mobi" || ext == "azw3" || ext == "kfx"
    }
}
