//
//  BookCoverView.swift
//  Books
//

import SwiftUI
import PDFKit
import CommonCrypto

private let coverImageCache = NSCache<NSString, NSImage>()

class CoverExtractionService {
    static let shared = CoverExtractionService()
    
    private let cacheDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".books1_cache")
            .appendingPathComponent("covers")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    func diskCacheURL(for path: String) -> URL {
        let hash = sha256(path)
        return cacheDir.appendingPathComponent("\(hash).jpg")
    }
    
    private func sha256(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "\(string.hashValue)" }
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    func extractCover(book: Book, width: CGFloat, height: CGFloat) -> NSImage? {
        // A. If book has a local path
        if let path = book.path, FileManager.default.fileExists(atPath: path) {
            let diskURL = diskCacheURL(for: path)
            if let diskImg = NSImage(contentsOf: diskURL) {
                return diskImg
            }
            
            // 1. PDF page 0 extraction
            if book.isPDF {
                if let doc = PDFDocument(url: URL(fileURLWithPath: path)),
                   let firstPage = doc.page(at: 0) {
                    let targetSize = CGSize(width: width * 2, height: height * 2)
                    let thumb = firstPage.thumbnail(of: targetSize, for: .cropBox)
                    if let tData = thumb.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tData),
                       let jpgData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) {
                        try? jpgData.write(to: diskURL)
                    }
                    return thumb
                }
            }
            
            // 2. Genuine EPUB OPF-standard cover extraction
            if book.isEPUB {
                if let img = extractGenuineEpubCover(epubPath: path) {
                    if let tData = img.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tData),
                       let jpgData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) {
                        try? jpgData.write(to: diskURL)
                    }
                    return img
                }
            }
        }
        
        // B. Check if book.cover is a local file or cache path
        if FileManager.default.fileExists(atPath: book.cover) {
            return NSImage(contentsOfFile: book.cover)
        }
        
        let expanded = (book.cover as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expanded) {
            return NSImage(contentsOfFile: expanded)
        }
        
        return nil
    }
    
    private func extractGenuineEpubCover(epubPath: String) -> NSImage? {
        // Step 1: List all files inside the EPUB zip
        let pList = Process()
        pList.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        pList.arguments = ["-Z1", epubPath]
        let pipeList = Pipe()
        pList.standardOutput = pipeList
        try? pList.run()
        let dataList = pipeList.fileHandleForReading.readDataToEndOfFile()
        pList.waitUntilExit()
        guard let listStr = String(data: dataList, encoding: .utf8) else { return nil }
        let entries = listStr.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let entrySet = Set(entries)
        
        // Step 2: Find the OPF file via META-INF/container.xml
        var opfPath: String? = nil
        if entrySet.contains("META-INF/container.xml") {
            let pCont = Process()
            pCont.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            pCont.arguments = ["-p", epubPath, "META-INF/container.xml"]
            let pipeCont = Pipe()
            pCont.standardOutput = pipeCont
            try? pCont.run()
            let contData = pipeCont.fileHandleForReading.readDataToEndOfFile()
            pCont.waitUntilExit()
            if let contStr = String(data: contData, encoding: .utf8) {
                let pattern = "full-path=[\"']([^\"']+)[\"']"
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: contStr, range: NSRange(contStr.startIndex..., in: contStr)),
                   let r = Range(match.range(at: 1), in: contStr) {
                    let cand = String(contStr[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if entrySet.contains(cand) {
                        opfPath = cand
                    }
                }
            }
        }
        
        if opfPath == nil {
            opfPath = entries.first(where: { $0.lowercased().hasSuffix(".opf") })
        }
        
        var coverEntry: String? = nil
        
        if let opf = opfPath, entrySet.contains(opf) {
            let opfDir = (opf as NSString).deletingLastPathComponent
            func resolveHref(_ href: String) -> String {
                let clean = href.components(separatedBy: "#")[0].components(separatedBy: "?")[0].trimmingCharacters(in: .whitespacesAndNewlines)
                if opfDir.isEmpty || opfDir == "." {
                    return clean
                }
                return (opfDir as NSString).appendingPathComponent(clean)
            }
            
            // Read OPF content
            let pOpf = Process()
            pOpf.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            pOpf.arguments = ["-p", epubPath, opf]
            let pipeOpf = Pipe()
            pOpf.standardOutput = pipeOpf
            try? pOpf.run()
            let opfData = pipeOpf.fileHandleForReading.readDataToEndOfFile()
            pOpf.waitUntilExit()
            if let opfStr = String(data: opfData, encoding: .utf8) {
                // Method A: EPUB 3 cover-image property
                let p3 = "<item[^>]*properties=[\"'][^\"']*cover-image[^\"']*[\"'][^>]*href=[\"']([^\"']+)[\"']"
                let p3Alt = "<item[^>]*href=[\"']([^\"']+)[\"'][^>]*properties=[\"'][^\"']*cover-image[^\"']*[\"']"
                for pattern in [p3, p3Alt] {
                    if coverEntry == nil,
                       let reg = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                       let match = reg.firstMatch(in: opfStr, range: NSRange(opfStr.startIndex..., in: opfStr)),
                       let r = Range(match.range(at: 1), in: opfStr) {
                        let res = resolveHref(String(opfStr[r]))
                        if entrySet.contains(res) {
                            coverEntry = res
                            break
                        }
                    }
                }
                
                // Method B: EPUB 2 <meta name="cover" content="item_id"/>
                if coverEntry == nil {
                    let pMeta = "<meta[^>]*name=[\"']cover[\"'][^>]*content=[\"']([^\"']+)[\"']"
                    let pMetaAlt = "<meta[^>]*content=[\"']([^\"']+)[\"'][^>]*name=[\"']cover[\"']"
                    for pattern in [pMeta, pMetaAlt] {
                        if coverEntry == nil,
                           let regMeta = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                           let matchMeta = regMeta.firstMatch(in: opfStr, range: NSRange(opfStr.startIndex..., in: opfStr)),
                           let rMeta = Range(matchMeta.range(at: 1), in: opfStr) {
                            let coverId = NSRegularExpression.escapedPattern(for: String(opfStr[rMeta]))
                            let pItem = "<item[^>]*id=[\"']\(coverId)[\"'][^>]*href=[\"']([^\"']+)[\"']"
                            let pItemAlt = "<item[^>]*href=[\"']([^\"']+)[\"'][^>]*id=[\"']\(coverId)[\"']"
                            for ip in [pItem, pItemAlt] {
                                if let regItem = try? NSRegularExpression(pattern: ip, options: .caseInsensitive),
                                   let matchItem = regItem.firstMatch(in: opfStr, range: NSRange(opfStr.startIndex..., in: opfStr)),
                                   let rItem = Range(matchItem.range(at: 1), in: opfStr) {
                                    let res = resolveHref(String(opfStr[rItem]))
                                    if entrySet.contains(res) {
                                        coverEntry = res
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Method C: Any image item with id containing "cover"
                if coverEntry == nil {
                    let pItems = "<item[^>]+>"
                    if let regItems = try? NSRegularExpression(pattern: pItems, options: .caseInsensitive) {
                        let matches = regItems.matches(in: opfStr, range: NSRange(opfStr.startIndex..., in: opfStr))
                        for m in matches {
                            guard let r = Range(m.range, in: opfStr) else { continue }
                            let tag = String(opfStr[r]).lowercased()
                            if tag.contains("image/") && (tag.contains("cover") || tag.contains("jacket") || tag.contains("img-0001")) {
                                let pHref = "href=[\"']([^\"']+)[\"']"
                                if let regHref = try? NSRegularExpression(pattern: pHref, options: .caseInsensitive),
                                   let mH = regHref.firstMatch(in: String(opfStr[r]), range: NSRange(opfStr[r].startIndex..., in: opfStr[r])),
                                   let rH = Range(mH.range(at: 1), in: opfStr[r]) {
                                    let res = resolveHref(String(opfStr[r][rH]))
                                    if entrySet.contains(res) {
                                        coverEntry = res
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Method D: Fallback to any file with "cover" or "jacket" in name
        if coverEntry == nil {
            let validExts = [".jpg", ".jpeg", ".png", ".webp"]
            let candidates = entries.filter { e in
                let l = e.lowercased()
                let base = (e as NSString).lastPathComponent.lowercased()
                return (base.contains("cover") || base.contains("jacket")) && validExts.contains(where: { l.hasSuffix($0) })
            }
            // Prefer exact "cover.jpg" / "cover.png"
            if let exact = candidates.first(where: { ( ($0 as NSString).lastPathComponent.lowercased().components(separatedBy: ".").first ?? "" ) == "cover" }) {
                coverEntry = exact
            } else {
                coverEntry = candidates.first
            }
        }
        
        // Step 3: Extract the image bytes
        guard let entryToExtract = coverEntry, entrySet.contains(entryToExtract) else { return nil }
        
        let pExtract = Process()
        pExtract.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        pExtract.arguments = ["-p", epubPath, entryToExtract]
        let pipeExtract = Pipe()
        pExtract.standardOutput = pipeExtract
        try? pExtract.run()
        let imgData = pipeExtract.fileHandleForReading.readDataToEndOfFile()
        pExtract.waitUntilExit()
        return NSImage(data: imgData)
    }
}

struct BookCoverView: View {
    let book: Book
    var width: CGFloat = 135
    var height: CGFloat { width * 1.5 } // Standard 2:3 Apple Books ratio
    var showTitle: Bool = true
    
    private var coverImage: NSImage? {
        let key = "\(book.path ?? book.title)_\(Int(width))" as NSString
        if let cached = coverImageCache.object(forKey: key) {
            return cached
        }
        
        if let img = CoverExtractionService.shared.extractCover(book: book, width: width, height: height) {
            coverImageCache.setObject(img, forKey: key)
            return img
        }
        
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .center) {
                if let img = coverImage {
                    // Authentic Apple Books Grid Card: Filled aspect ratio with exact boundaries
                    // Ensures all covers across the grid align with consistent heights and shadows
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipped()
                        .cornerRadius(4)
                        .shadow(
                            color: Color.black.opacity(0.18),
                            radius: 6,
                            x: 0,
                            y: 3
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.black.opacity(0.10), lineWidth: 0.5)
                        )
                } else {
                    // Fallback textured book cover (strictly bounded to identical 2:3 dimensions)
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.20, green: 0.22, blue: 0.26),
                                Color(red: 0.12, green: 0.13, blue: 0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        VStack(spacing: 6) {
                            Text(book.title)
                                .font(.system(size: max(width * 0.08, 10), weight: .bold, design: .serif))
                                .multilineTextAlignment(.center)
                                .lineLimit(5)
                                .foregroundColor(.white.opacity(0.92))
                                .padding(.horizontal, 8)
                            
                            Text(book.author)
                                .font(.system(size: max(width * 0.065, 9), weight: .regular))
                                .foregroundColor(.white.opacity(0.60))
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                        }
                    }
                    .frame(width: width, height: height)
                    .cornerRadius(4)
                    .shadow(
                        color: Color.black.opacity(0.15),
                        radius: 6,
                        x: 0,
                        y: 3
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.black.opacity(0.12), lineWidth: 0.5)
                    )
                }
            }
            .frame(width: width, height: height)
            
            if showTitle {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Text(book.author)
                        .font(.system(size: 11, weight: .regular))
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
                .frame(width: width, alignment: .leading)
            }
        }
    }
}
