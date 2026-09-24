//
//  EmbeddedReaderView.swift
//  Folio / Books
//
//  Apple Books HIG Pixel-Perfect Implementation
//

import SwiftUI
import WebKit
import PDFKit

class CustomPDFView: PDFView {
    var onAddAnnotation: ((String, String, String, Int) -> Void)? = nil
    
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        if let sel = self.currentSelection, let selString = sel.string, !selString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            menu.addItem(NSMenuItem.separator())
            
            let hlMenu = NSMenu(title: "Highlight")
            let colors: [(String, String, NSColor)] = [
                ("Yellow", "#FFE270", NSColor(srgbRed: 1.0, green: 0.886, blue: 0.439, alpha: 0.5)),
                ("Green", "#A8F596", NSColor(srgbRed: 0.659, green: 0.961, blue: 0.588, alpha: 0.5)),
                ("Blue", "#92D6FF", NSColor(srgbRed: 0.573, green: 0.839, blue: 1.0, alpha: 0.5)),
                ("Pink", "#FFB3D9", NSColor(srgbRed: 1.0, green: 0.702, blue: 0.851, alpha: 0.5)),
                ("Purple", "#D2B4FF", NSColor(srgbRed: 0.824, green: 0.706, blue: 1.0, alpha: 0.5))
            ]
            
            for (name, hex, nsCol) in colors {
                let item = NSMenuItem(title: "\(name) Highlight", action: #selector(highlightSelectionWithColor(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = ["hex": hex, "color": nsCol]
                hlMenu.addItem(item)
            }
            
            let hlSubmenuItem = NSMenuItem(title: "Highlight", action: nil, keyEquivalent: "")
            hlSubmenuItem.submenu = hlMenu
            menu.addItem(hlSubmenuItem)
            
            let underItem = NSMenuItem(title: "Underline Selection", action: #selector(underlineCurrentSelection), keyEquivalent: "")
            underItem.target = self
            menu.addItem(underItem)
            
            let strikeItem = NSMenuItem(title: "Strikethrough Selection", action: #selector(strikeCurrentSelection), keyEquivalent: "")
            strikeItem.target = self
            menu.addItem(strikeItem)
            
            let noteItem = NSMenuItem(title: "Add Note", action: #selector(addNoteToSelection), keyEquivalent: "")
            noteItem.target = self
            menu.addItem(noteItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        let openPreviewItem = NSMenuItem(title: "Open in Preview (View Images/Diagrams)", action: #selector(openInPreview), keyEquivalent: "")
        openPreviewItem.target = self
        menu.addItem(openPreviewItem)
        
        return menu
    }
    
    @objc func highlightSelectionWithColor(_ sender: NSMenuItem) {
        guard let sel = currentSelection,
              let dict = sender.representedObject as? [String: Any],
              let hex = dict["hex"] as? String,
              let col = dict["color"] as? NSColor else { return }
        for page in sel.pages {
            let bounds = sel.bounds(for: page)
            let annot = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            annot.color = col
            page.addAnnotation(annot)
        }
        saveDocumentIfPossible()
        if let page = sel.pages.first, let doc = document, let text = sel.string {
            let pageIdx = doc.index(for: page)
            onAddAnnotation?(text.trimmingCharacters(in: .whitespacesAndNewlines), "", hex, pageIdx)
        }
    }
    
    @objc func highlightCurrentSelection() {
        guard let sel = currentSelection else { return }
        for page in sel.pages {
            let bounds = sel.bounds(for: page)
            let annot = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            annot.color = NSColor.systemYellow.withAlphaComponent(0.4)
            page.addAnnotation(annot)
        }
        saveDocumentIfPossible()
        if let page = sel.pages.first, let doc = document, let text = sel.string {
            let pageIdx = doc.index(for: page)
            onAddAnnotation?(text.trimmingCharacters(in: .whitespacesAndNewlines), "", "#FFE270", pageIdx)
        }
    }
    
    @objc func underlineCurrentSelection() {
        guard let sel = currentSelection else { return }
        for page in sel.pages {
            let bounds = sel.bounds(for: page)
            let annot = PDFAnnotation(bounds: bounds, forType: .underline, withProperties: nil)
            annot.color = NSColor.systemOrange
            page.addAnnotation(annot)
        }
        saveDocumentIfPossible()
        if let page = sel.pages.first, let doc = document, let text = sel.string {
            let pageIdx = doc.index(for: page)
            onAddAnnotation?(text.trimmingCharacters(in: .whitespacesAndNewlines), "", "#FF9500", pageIdx)
        }
    }
    
    @objc func strikeCurrentSelection() {
        guard let sel = currentSelection else { return }
        for page in sel.pages {
            let bounds = sel.bounds(for: page)
            let annot = PDFAnnotation(bounds: bounds, forType: .strikeOut, withProperties: nil)
            annot.color = NSColor.systemRed
            page.addAnnotation(annot)
        }
        saveDocumentIfPossible()
    }
    
    @objc func addNoteToSelection() {
        guard let sel = currentSelection, let page = sel.pages.first else { return }
        let bounds = sel.bounds(for: page)
        let noteRect = NSRect(x: bounds.origin.x, y: bounds.origin.y, width: 24, height: 24)
        let annot = PDFAnnotation(bounds: noteRect, forType: .text, withProperties: nil)
        annot.contents = "Note"
        annot.color = NSColor.systemYellow
        page.addAnnotation(annot)
        saveDocumentIfPossible()
        if let doc = document, let text = sel.string {
            let pageIdx = doc.index(for: page)
            onAddAnnotation?(text.trimmingCharacters(in: .whitespacesAndNewlines), "Note", "#FFE270", pageIdx)
        }
    }
    
    @objc func openInPreview() {
        guard let doc = document, let url = doc.documentURL else { return }
        NSWorkspace.shared.open(url)
    }
    
    func saveDocumentIfPossible() {
        guard let doc = document, let url = doc.documentURL else { return }
        doc.write(to: url)
    }
}

struct PDFOutlineNode: Identifiable {
    let id = UUID()
    let title: String
    let pageIndex: Int
}

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

struct NativePDFKitView: NSViewRepresentable {
    let url: URL
    @Binding var targetPage: Int?
    var onPageChange: ((Int, Int) -> Void)? = nil
    var onAddAnnotation: ((String, String, String, Int) -> Void)? = nil
    
    private var resolvedURL: URL {
        let p = (url.path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: p)
    }
    
    func makeNSView(context: Context) -> CustomPDFView {
        let pdfView = CustomPDFView()
        pdfView.onAddAnnotation = onAddAnnotation
        if let doc = PDFDocument(url: resolvedURL) {
            pdfView.document = doc
        }
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = .windowBackgroundColor
        pdfView.layoutDocumentView()
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        return pdfView
    }
    
    func updateNSView(_ pdfView: CustomPDFView, context: Context) {
        pdfView.onAddAnnotation = onAddAnnotation
        if pdfView.document == nil || pdfView.document?.documentURL?.path != resolvedURL.path {
            if let doc = PDFDocument(url: resolvedURL) {
                pdfView.document = doc
                pdfView.autoScales = true
                pdfView.layoutDocumentView()
            }
        }
        if let target = targetPage, let doc = pdfView.document, target >= 0 && target < doc.pageCount {
            if let page = doc.page(at: target), pdfView.currentPage != page {
                pdfView.go(to: page)
            }
            DispatchQueue.main.async {
                self.targetPage = nil
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: NativePDFKitView
        init(_ parent: NativePDFKitView) {
            self.parent = parent
        }
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let curPage = pdfView.currentPage,
                  let doc = pdfView.document else { return }
            let pageIndex = doc.index(for: curPage)
            let total = doc.pageCount
            parent.onPageChange?(pageIndex, total)
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    var onWindow: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let w = view.window {
                onWindow(w)
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        if let w = nsView.window {
            onWindow(w)
        }
    }
}

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

struct BookmarkItem: Identifiable, Codable {
    let id: UUID
    let chapterIndex: Int
    let spreadIndex: Int
    let chapterTitle: String
    let pageNumber: Int
    let date: Date
}

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

//
// Apple Books Circular Hover Tool Button (Pixel-perfect matching Screenshot NT3LMz)
// Eliminates macOS default blue focus square and provides subtle circular hover tint
//
struct AppleBooksIconButton: View {
    let icon: String?
    let text: String?
    let isActive: Bool
    let activeColor: Color?
    let tooltip: String
    let action: () -> Void
    
    @State private var isHovered: Bool = false
    
    init(systemName: String, isActive: Bool = false, activeColor: Color? = nil, tooltip: String = "", action: @escaping () -> Void) {
        self.icon = systemName
        self.text = nil
        self.isActive = isActive
        self.activeColor = activeColor
        self.tooltip = tooltip
        self.action = action
    }
    
    init(text: String, isActive: Bool = false, activeColor: Color? = nil, tooltip: String = "", action: @escaping () -> Void) {
        self.icon = nil
        self.text = text
        self.isActive = isActive
        self.activeColor = activeColor
        self.tooltip = tooltip
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Subtle circular hover tint matching Screenshot NT3LMz (NO blue square)
                Circle()
                    .fill(isHovered ? Color.primary.opacity(0.08) : (isActive ? Color.primary.opacity(0.12) : Color.clear))
                    .frame(width: 28, height: 28)
                
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(isActive ? (activeColor ?? .primary) : .primary.opacity(0.85))
                } else if let text = text {
                    Text(text)
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundColor(isActive ? (activeColor ?? .primary) : .primary.opacity(0.85))
                }
            }
            .frame(width: 32, height: 32)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
        .help(tooltip)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = h
            }
        }
    }
}

struct EmbeddedReaderView: View {
    @Environment(\.dismiss) var dismiss
    var book: Book
    var isStandaloneWindow: Bool = false
    var onClose: (() -> Void)? = nil
    
    @State private var currentChapterIndex: Int = 0
    @State private var totalChapters: Int = 1
    @State private var firstTextChapter: Int = 0
    @State private var chapterContent: String = ""
    @State private var chapterTitle: String = ""
    @State private var isLoading: Bool = true
    @State private var isInitialBookLoad: Bool = true
    
    // Page Metrics (Parity with Screenshot DcKW6y & f27b11)
    @State private var currentSpreadIndex: Int = 1
    @State private var totalSpreadsInChapter: Int = 1
    @State private var pagesLeftInChapter: Int = 0
    @State private var triggerNextPage: Int = 0
    @State private var triggerPrevPage: Int = 0
    
    // Popovers
    @State private var showTOCPopover: Bool = false
    @State private var showBookmarksPopover: Bool = false
    @State private var showNotesPopover: Bool = false
    @State private var showAppearancePopover: Bool = false
    @State private var showSearchPopover: Bool = false
    @State private var showCustomizeSheet: Bool = false
    @State private var showFloatingAudio: Bool = false
    @State private var targetPDFPage: Int? = nil
    @State private var pdfOutline: [PDFOutlineNode] = []
    
    // Accurate Table of Contents & Estimated Pages
    @State private var bookTOC: [BookTOCEntry] = []
    @State private var estimatedTotalPages: Int = 1
    @State private var spineStartPages: [Int] = []
    @State private var spineBasePages: [Int] = []
    
    // Bookmarks, Notes & Highlights
    @State private var isBookmarked: Bool = false
    @State private var bookmarks: [BookmarkItem] = []
    @State private var notes: [NoteItem] = []
    @State private var editingNoteId: UUID? = nil
    @State private var newNoteText: String = ""
    @State private var selectedQuoteText: String = ""
    @State private var showAddNoteSheet: Bool = false
    @State private var searchQuery: String = ""
    @State private var fontSize: Double = 18.0
    @State private var selectedFontFamily: String = "Original"
    @State private var readerTheme: String = "Original" // Original, Quiet, Paper, Bold, Calm, Focus
    @State private var isCustomizeEnabled: Bool = true
    @State private var isTwoPageSpread: Bool = true
    @State private var isBoldText: Bool = false
    @State private var isEditMode: Bool = false
    @State private var currentVisibleSnippet: String = ""
    @State private var lineSpacing: Double = 1.74
    @State private var characterSpacing: Double = 0.0
    @State private var wordSpacing: Double = 0.0
    @State private var marginScale: Double = 0.0
    @State private var columnsOption: String = "auto"
    @State private var justifyText: Bool = true
    @State private var seekToSpread: Int = 1
    @State private var isHoveringScrubber: Bool = false
    
    // High-Precision Window & Reading Goals Focus Tracking
    @State private var hostingWindow: NSWindow? = nil
    @State private var lastTickTime: Date? = nil
    @State private var fractionalSeconds: Double = 0.0
    @State private var hasMarkedCurrentlyReading: Bool = false
    
    private var coverImage: NSImage? {
        CoverExtractionService.shared.extractCover(book: book, width: 280, height: 420)
    }
    
    private var dynamicScaleRatio: Double {
        if currentChapterIndex < spineBasePages.count && spineBasePages[currentChapterIndex] > 0 {
            let base = Double(spineBasePages[currentChapterIndex])
            let actual = Double(max(1, totalSpreadsInChapter))
            let r = actual / base
            return max(0.2, min(5.0, r))
        }
        return 1.0
    }
    
    private var overallTotalPages: Int {
        if book.isPDF {
            return max(1, totalChapters)
        }
        if estimatedTotalPages > 1 {
            let scaled = Int(round(Double(estimatedTotalPages) * dynamicScaleRatio))
            return max(1, scaled)
        }
        if totalChapters <= 1 {
            return max(1, totalSpreadsInChapter)
        }
        return max(totalChapters * max(1, totalSpreadsInChapter), 1)
    }
    
    private var overallCurrentPage: Int {
        if book.isPDF {
            return min(overallTotalPages, currentChapterIndex + 1)
        }
        if currentChapterIndex < spineStartPages.count {
            let start = spineStartPages[currentChapterIndex]
            let scaledStart = Int(round(Double(start) * dynamicScaleRatio))
            let offset = max(0, currentSpreadIndex - 1)
            return max(1, min(overallTotalPages, scaledStart + offset))
        }
        if totalChapters <= 1 {
            return currentSpreadIndex
        }
        let perChapter = max(1, totalSpreadsInChapter)
        let chapterBase = currentChapterIndex * perChapter
        let spreadOffset = min(perChapter - 1, currentSpreadIndex - 1)
        return max(1, min(overallTotalPages, chapterBase + spreadOffset + 1))
    }
    
    private var overallProgress: CGFloat {
        if overallTotalPages <= 1 { return 0 }
        return CGFloat(overallCurrentPage - 1) / CGFloat(overallTotalPages - 1)
    }
    
    private var readingSpeedFormatted: String {
        return readingSpeed.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", readingSpeed) : String(format: "%.1f", readingSpeed)
    }
    
    private func cycleSpeed() {
        let speeds: [Double] = [0.8, 1.0, 1.2, 1.5, 2.0]
        if let idx = speeds.firstIndex(of: readingSpeed) {
            readingSpeed = speeds[(idx + 1) % speeds.count]
        } else {
            readingSpeed = 1.0
        }
    }
    
    private func shortVoiceName(_ id: String) -> String {
        for (vId, name) in voices {
            if vId == id {
                let parts = name.components(separatedBy: " ")
                return parts.first ?? name
            }
        }
        return "Voice"
    }
    
    // Kokoro Audio & Speed
    @State private var isPlayingAudio: Bool = false
    @State private var readingSpeed: Double = 1.0
    @State private var selectedVoice: String = "af_heart"
    @State private var ttsProcess: Process? = nil
    @State private var readingTimer: Timer? = nil
    @State private var isControlsVisible: Bool = true
    @State private var hideControlsTimer: Timer? = nil
    @State private var lastActivityTime: Date = Date()
    @State private var activeReadingSeconds: Int = 0
    
    var hasActivePopover: Bool {
        showTOCPopover || showBookmarksPopover || showNotesPopover || showAppearancePopover || showSearchPopover || showCustomizeSheet || showFloatingAudio
    }
    
    private func registerMouseActivity() {
        lastActivityTime = Date()
        withAnimation(.easeInOut(duration: 0.22)) {
            isControlsVisible = true
        }
        hideControlsTimer?.invalidate()
        if !hasActivePopover {
            hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                DispatchQueue.main.async {
                    if !self.hasActivePopover {
                        withAnimation(.easeInOut(duration: 0.28)) {
                            self.isControlsVisible = false
                        }
                    }
                }
            }
        }
    }
    
    private func handleWindowHover(isHovering: Bool) {
        if isHovering {
            registerMouseActivity()
        } else {
            if !hasActivePopover {
                hideControlsTimer?.invalidate()
                withAnimation(.easeInOut(duration: 0.22)) {
                    isControlsVisible = false
                }
            }
        }
    }
    
    let voices = [
        ("af_heart", "Heart (Warm & Melodic)"),
        ("af_bella", "Bella (Expressive)"),
        ("af_nicole", "Nicole (Clear Narrator)"),
        ("af_sarah", "Sarah (Gentle & Smooth)"),
        ("am_michael", "Michael (Rich & Deep)"),
        ("am_fenrir", "Fenrir (Crisp & Resonant)"),
        ("bf_emma", "Emma (British Female)"),
        ("bm_george", "George (British Male)"),
        ("bm_fable", "Fable (British Storyteller)"),
        ("if_sara", "Sara (Italian Female)"),
        ("im_nicola", "Nicola (Italian Male)")
    ]
    
    let fontFamilies = [
        "Original",
        "Athelas",
        "Charter",
        "Georgia",
        "Iowan Old Style",
        "New York",
        "Palatino",
        "San Francisco",
        "Seravek",
        "Times New Roman"
    ]
    
    let themePalettes: [(String, String, Color, Color)] = [
        ("Original", "Original", Color.white, Color(hex: "#1C1C1E")),
        ("Quiet", "Quiet", Color(hex: "#2C2C2E"), Color(hex: "#E5E5EA")),
        ("Paper", "Paper", Color(hex: "#F5EFE6"), Color(hex: "#3D2E1E")),
        ("Bold", "Bold", Color(hex: "#000000"), Color.white),
        ("Calm", "Calm", Color(hex: "#F8EFE4"), Color(hex: "#3D2F24")),
        ("Focus", "Focus", Color(hex: "#EAEAEA"), Color(hex: "#1C1C1E"))
    ]
    
    var themeBackgroundColor: Color {
        switch readerTheme {
        case "Quiet": return Color(hex: "#2C2C2E")
        case "Paper": return Color(hex: "#F5EFE6")
        case "Bold": return Color(hex: "#000000")
        case "Calm": return Color(hex: "#F8EFE4")
        case "Focus": return Color(hex: "#EAEAEA")
        default: return Color.white
        }
    }
    
    var themeTextColor: Color {
        switch readerTheme {
        case "Quiet", "Bold": return Color(hex: "#E5E5EA")
        case "Paper": return Color(hex: "#3D2E1E")
        case "Calm": return Color(hex: "#3D2F24")
        default: return Color(hex: "#1C1C1E")
        }
    }
    
    var body: some View {
        ZStack {
            // Full window seamless background matching theme
            themeBackgroundColor
                .ignoresSafeArea()
            
            if isInitialBookLoad && isLoading {
                VStack(spacing: 24) {
                    if let img = coverImage {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 460)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.24), radius: 24, x: 0, y: 12)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(width: 280, height: 420)
                            .overlay(
                                Text(book.title)
                                    .font(.system(size: 16, weight: .bold, design: .serif))
                                    .multilineTextAlignment(.center)
                                    .padding(24)
                            )
                            .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 8)
                    }
                    
                    // Classic Apple indeterminate circular progress spinner
                    ProgressView()
                        .controlSize(.regular)
                        .scaleEffect(0.95)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            } else if book.isPDF, let path = book.path {
                NativePDFKitView(url: URL(fileURLWithPath: path), targetPage: $targetPDFPage, onPageChange: { cur, tot in
                    DispatchQueue.main.async {
                        self.currentChapterIndex = cur
                        self.totalChapters = max(1, tot)
                        self.updateBookmarkState()
                    }
                }, onAddAnnotation: { text, note, colorHex, pageIdx in
                    DispatchQueue.main.async {
                        self.addAnnotation(text: text, note: note, colorHex: colorHex)
                    }
                })
                .ignoresSafeArea()
            } else {
                // Full-window WebKit Page View
                BookWebView(
                    htmlContent: chapterContent,
                    isTwoPageSpread: isTwoPageSpread,
                    readerTheme: readerTheme,
                    fontSize: fontSize,
                    fontFamily: isCustomizeEnabled ? selectedFontFamily : "Original",
                    isBoldText: isCustomizeEnabled ? isBoldText : false,
                    isEditMode: isEditMode,
                    pageNumber: currentSpreadIndex,
                    bookPath: book.path ?? "",
                    chapterIndex: currentChapterIndex,
                    savedAnnotations: notes.filter { $0.chapterIndex == currentChapterIndex },
                    triggerNextPage: triggerNextPage,
                    triggerPrevPage: triggerPrevPage,
                    seekToSpread: seekToSpread,
                    lineSpacing: lineSpacing,
                    characterSpacing: characterSpacing,
                    wordSpacing: wordSpacing,
                    marginScale: marginScale,
                    columnsOption: columnsOption,
                    justifyText: justifyText,
                    onMouseActivity: {
                        registerMouseActivity()
                    },
                    onAddAnnotation: { text, note, colorHex in
                        DispatchQueue.main.async {
                            self.addAnnotation(text: text, note: note, colorHex: colorHex)
                        }
                    },
                    onPromptNote: { text in
                        DispatchQueue.main.async {
                            self.selectedQuoteText = text
                            self.newNoteText = ""
                            self.showAddNoteSheet = true
                            self.showNotesPopover = true
                        }
                    },
                    onDeleteAnnotation: { text in
                        DispatchQueue.main.async {
                            self.deleteAnnotationByText(text)
                        }
                    },
                    onVisibleSnippet: { snippet in
                        DispatchQueue.main.async {
                            self.currentVisibleSnippet = snippet
                        }
                    },
                    onPageMetrics: { cur, tot, left in
                        DispatchQueue.main.async {
                            self.currentSpreadIndex = cur
                            self.totalSpreadsInChapter = max(1, tot)
                            self.pagesLeftInChapter = max(0, left)
                            self.updateBookmarkState()
                        }
                    },
                    onNextChapter: {
                        if currentChapterIndex < totalChapters - 1 {
                            currentChapterIndex += 1
                            currentSpreadIndex = 1
                            seekToSpread = 1
                            loadChapter()
                            updateBookmarkState()
                        }
                    },
                    onPrevChapter: {
                        if currentChapterIndex > 0 {
                            currentChapterIndex -= 1
                            currentSpreadIndex = 1
                            seekToSpread = 1
                            loadChapter()
                            updateBookmarkState()
                        }
                    }
                )
                .ignoresSafeArea()
                
                // Floating Chevrons (< and >) on sides
                HStack {
                    Button(action: { triggerPrevPage += 1 }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(Color.primary.opacity(0.4))
                            .padding(.vertical, 32)
                            .padding(.horizontal, 10)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .help("Previous Page")
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    
                    Spacer()
                    
                    Button(action: { triggerNextPage += 1 }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(Color.primary.opacity(0.4))
                            .padding(.vertical, 32)
                            .padding(.horizontal, 10)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .help("Next Page")
                    .keyboardShortcut(.rightArrow, modifiers: [])
                }
                .padding(.horizontal, 4)
                .opacity(isControlsVisible || hasActivePopover ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.22), value: isControlsVisible || hasActivePopover)
                .allowsHitTesting(isControlsVisible || hasActivePopover)
                
                // Floating Top Controls Bar (Pixel-perfect matching Screenshot NT3LMz)
                VStack {
                    ZStack(alignment: .center) {
                        // Dead-Center Floating Title Capsule (mathematically centered on central spine crease)
                        Text(book.title)
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .lineLimit(1)
                            .foregroundColor(.primary.opacity(0.75))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.75))
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
                            )
                        
                        HStack(alignment: .center) {
                            // Left Floating Capsule (TOC, Bookmarks list, Notes)
                            HStack(spacing: 8) {
                                if !isStandaloneWindow {
                                    AppleBooksIconButton(systemName: "chevron.left", tooltip: "Back to Library") {
                                        stopAudio()
                                        dismiss()
                                    }
                                    .padding(2)
                                    .background(
                                        Circle()
                                            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                                            .background(.ultraThinMaterial, in: Circle())
                                            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                                    )
                                } else {
                                    // Leave room for macOS traffic lights
                                    Spacer().frame(width: 58)
                                }
                                
                                HStack(spacing: 2) {
                                    AppleBooksIconButton(systemName: "list.bullet", isActive: showTOCPopover, tooltip: "Contents") {
                                        showTOCPopover.toggle()
                                    }
                                    .popover(isPresented: $showTOCPopover) {
                                        tocPopoverView
                                    }
                                    
                                    AppleBooksIconButton(systemName: "bookmark", isActive: showBookmarksPopover, tooltip: "Bookmarks") {
                                        showBookmarksPopover.toggle()
                                    }
                                    .popover(isPresented: $showBookmarksPopover) {
                                        bookmarksPopoverView
                                    }
                                    
                                    AppleBooksIconButton(systemName: "square.text.square", isActive: showNotesPopover, tooltip: "Highlights & Notes") {
                                        showNotesPopover.toggle()
                                    }
                                    .popover(isPresented: $showNotesPopover) {
                                        notesPopoverView
                                    }
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                                        .background(.ultraThinMaterial, in: Capsule())
                                        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                                )
                            }
                            
                            Spacer()
                            
                            // Right Floating Capsules (aA + Search capsule, Bookmark circle, Audio circle)
                            HStack(spacing: 10) {
                                // aA & Search Capsule
                                HStack(spacing: 2) {
                                    AppleBooksIconButton(text: "aA", isActive: showAppearancePopover, tooltip: "Themes & Settings") {
                                        showAppearancePopover.toggle()
                                    }
                                    .popover(isPresented: $showAppearancePopover) {
                                        themesAndSettingsPopoverView
                                    }
                                    
                                    AppleBooksIconButton(systemName: "magnifyingglass", isActive: showSearchPopover, tooltip: "Search in Book") {
                                        showSearchPopover.toggle()
                                    }
                                    .popover(isPresented: $showSearchPopover) {
                                        HStack {
                                            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                                            TextField("Search chapter...", text: $searchQuery)
                                                .textFieldStyle(.plain)
                                        }
                                        .padding(10)
                                        .frame(width: 240)
                                    }
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                                        .background(.ultraThinMaterial, in: Capsule())
                                        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                                )
                                
                                // Bookmark Button Circle
                                AppleBooksIconButton(
                                    systemName: isBookmarked ? "bookmark.fill" : "bookmark",
                                    isActive: isBookmarked,
                                    activeColor: Color(red: 0.95, green: 0.22, blue: 0.22),
                                    tooltip: "Bookmark Page"
                                ) {
                                    toggleBookmark()
                                }
                                .padding(3)
                                .background(
                                    Circle()
                                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                                        .background(.ultraThinMaterial, in: Circle())
                                        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                                )
                                
                                // Read Aloud (Headphones) Button Circle
                                AppleBooksIconButton(
                                    systemName: isPlayingAudio ? "speaker.wave.2.fill" : "headphones",
                                    isActive: isPlayingAudio || showFloatingAudio,
                                    activeColor: Color(red: 0.16, green: 0.50, blue: 0.98),
                                    tooltip: isPlayingAudio ? "Audio Narration (Playing)" : "Listen (Read Aloud)"
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showFloatingAudio.toggle()
                                    }
                                    if showFloatingAudio && !isPlayingAudio {
                                        startAudio()
                                    }
                                }
                                .padding(3)
                                .background(
                                    Circle()
                                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                                        .background(.ultraThinMaterial, in: Circle())
                                        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                                )
                            }
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 72)
                    .padding(.top, 6)
                    .opacity(isControlsVisible || hasActivePopover ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.22), value: isControlsVisible || hasActivePopover)
                    .allowsHitTesting(isControlsVisible || hasActivePopover)
                    
                    Spacer()
                    
                    //
                    // Floating Frosted Audio Player Capsule
                    //
                    if showFloatingAudio {
                        HStack(spacing: 12) {
                            Button(action: {
                                toggleAudio()
                            }) {
                                Image(systemName: isPlayingAudio ? "pause.fill" : "play.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)
                            .help(isPlayingAudio ? "Pause Narration" : "Play Narration")
                            
                            Menu {
                                ForEach(voices, id: \.0) { vId, name in
                                    Button(action: {
                                        selectedVoice = vId
                                        if isPlayingAudio {
                                            stopAudio()
                                            startAudio()
                                        }
                                    }) {
                                        HStack {
                                            Text(name)
                                            if selectedVoice == vId {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.wave.2")
                                        .font(.system(size: 11))
                                    Text(shortVoiceName(selectedVoice))
                                        .font(.system(size: 11, weight: .medium))
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 9))
                                }
                                .foregroundColor(.secondary)
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                            
                            Button(action: {
                                cycleSpeed()
                                if isPlayingAudio {
                                    stopAudio()
                                    startAudio()
                                }
                            }) {
                                Text("\(readingSpeedFormatted)×")
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                            .help("Playback Speed")
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    showFloatingAudio = false
                                }
                                if isPlayingAudio {
                                    stopAudio()
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Close Audio Player")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                                .background(.ultraThinMaterial, in: Capsule())
                                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 3)
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 6)
                    }
                    
                    //
                    // Native Apple Books Minimal Page Indicator & Scrubber (Screenshot RalbJx)
                    //
                    VStack(spacing: 5) {
                        HStack(spacing: 7) {
                            Text(pagesLeftText)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(Color.secondary.opacity(0.95))
                            
                            Text("•")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(Color.secondary.opacity(0.4))
                            
                            Text("Page \(currentSpreadIndex) of \(totalSpreadsInChapter)")
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundColor(Color.secondary.opacity(0.80))
                            
                            if overallTotalPages > totalSpreadsInChapter {
                                Text("(\(overallCurrentPage) of \(overallTotalPages))")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(Color.secondary.opacity(0.60))
                            }
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                                .background(.ultraThinMaterial, in: Capsule())
                        )
                        .opacity(0.92)
                        
                        // Scrubber Capsule Handle / Drag Track (fades on hover)
                        GeometryReader { geo in
                            let availableWidth = geo.size.width
                            let capsuleWidth: CGFloat = 34
                            let capsuleHeight: CGFloat = 5
                            let progress = overallProgress
                            let maxOffset = max(0, availableWidth - capsuleWidth)
                            let currentOffset = maxOffset * progress
                            
                            ZStack(alignment: .leading) {
                                // Subtle track line visible when hovering
                                Capsule()
                                    .fill(Color.primary.opacity(isHoveringScrubber ? 0.08 : 0.0))
                                    .frame(height: 2)
                                
                                // Dark Gray Scrubber Capsule (Screenshot RalbJx)
                                Capsule()
                                    .fill(Color(nsColor: .labelColor).opacity(0.48))
                                    .frame(width: capsuleWidth, height: capsuleHeight)
                                    .offset(x: currentOffset)
                            }
                            .frame(height: capsuleHeight)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { val in
                                        isHoveringScrubber = true
                                        registerMouseActivity()
                                        guard maxOffset > 0 else { return }
                                        let pct = max(0, min(1, (val.location.x - capsuleWidth / 2) / maxOffset))
                                        if totalChapters > 1 {
                                            let targetChapter = min(totalChapters - 1, Int(pct * Double(totalChapters)))
                                            if targetChapter != currentChapterIndex {
                                                currentChapterIndex = targetChapter
                                                loadChapter()
                                            }
                                        } else {
                                            let target = max(1, min(totalSpreadsInChapter, Int(round(Double(pct) * Double(totalSpreadsInChapter - 1))) + 1))
                                            if target != currentSpreadIndex {
                                                currentSpreadIndex = target
                                                seekToSpread = target
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        registerMouseActivity()
                                    }
                            )
                            .onHover { h in
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isHoveringScrubber = h
                                }
                                if h { registerMouseActivity() }
                            }
                        }
                        .frame(width: 320, height: 8)
                        .opacity(isControlsVisible || isHoveringScrubber || hasActivePopover ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.22), value: isControlsVisible || isHoveringScrubber || hasActivePopover)
                        .allowsHitTesting(isControlsVisible || isHoveringScrubber || hasActivePopover)
                    }
                    .padding(.bottom, 6)
                }
            }
            

            
            // Background keyboard navigation shortcuts (Arrow Up/Down, Space)
            Group {
                Button("") { triggerNextPage += 1 }.keyboardShortcut(.downArrow, modifiers: [])
                Button("") { triggerPrevPage += 1 }.keyboardShortcut(.upArrow, modifiers: [])
                Button("") { triggerNextPage += 1 }.keyboardShortcut(.space, modifiers: [])
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .frame(minWidth: 860, minHeight: 640)
        .onHover { isHovered in
            handleWindowHover(isHovering: isHovered)
        }
        .onChange(of: hasActivePopover) { _, active in
            if active {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isControlsVisible = true
                }
                hideControlsTimer?.invalidate()
            } else {
                registerMouseActivity()
            }
        }
        .background(WindowAccessor { win in
            self.hostingWindow = win
            self.lastTickTime = Date()
            self.lastActivityTime = Date()
        })
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notif in
            if let w = notif.object as? NSWindow, (self.hostingWindow == nil || w == self.hostingWindow) {
                self.lastTickTime = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notif in
            if let w = notif.object as? NSWindow, (self.hostingWindow == nil || w == self.hostingWindow) {
                self.lastTickTime = Date()
                self.lastActivityTime = Date()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResizeNotification)) { notif in
            if let w = notif.object as? NSWindow, (self.hostingWindow == nil || w == self.hostingWindow) {
                self.registerMouseActivity()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            self.lastTickTime = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if self.hostingWindow?.isKeyWindow == true {
                self.lastTickTime = Date()
                self.lastActivityTime = Date()
            }
        }
        .onAppear {
            EmbeddedReaderView.killGlobalAudio()
            startReadingTimer()
            let bookKey = book.path ?? book.title
            self.bookmarks = BookmarksStorage.shared.loadBookmarks(for: bookKey)
            self.notes = NotesStorage.shared.loadNotes(for: bookKey)
            self.updateBookmarkState()
            self.loadMetadata()
            
            if book.isPDF, let path = book.path {
                let resolved = (path as NSString).expandingTildeInPath
                if let doc = PDFDocument(url: URL(fileURLWithPath: resolved)) {
                    self.totalChapters = max(1, doc.pageCount)
                    self.pdfOutline = extractPDFOutline(from: doc)
                }
                self.isLoading = false
                self.isInitialBookLoad = false
            } else {
                loadChapter()
            }
            registerMouseActivity()
        }
        .onDisappear {
            EmbeddedReaderView.killGlobalAudio()
            stopAudio()
            stopReadingTimer()
            hideControlsTimer?.invalidate()
        }
        .sheet(isPresented: $showCustomizeSheet) {
            CustomizeThemeSheetView(
                isPresented: $showCustomizeSheet,
                selectedFontFamily: $selectedFontFamily,
                isBoldText: $isBoldText,
                isCustomizeEnabled: $isCustomizeEnabled,
                readerTheme: $readerTheme,
                lineSpacing: $lineSpacing,
                characterSpacing: $characterSpacing,
                wordSpacing: $wordSpacing,
                marginScale: $marginScale,
                columnsOption: $columnsOption,
                justifyText: $justifyText,
                fontFamilies: fontFamilies
            )
        }
    }
    
    var pagesLeftText: String {
        if pagesLeftInChapter <= 0 {
            return "Last page in chapter"
        } else if pagesLeftInChapter == 1 {
            return "1 page left in chapter"
        } else {
            return "\(pagesLeftInChapter) pages left in chapter"
        }
    }
    
    //
    // Popovers Matching Apple Books UI
    //
    
    // 1. Contents Popover (Screenshot UXX36N)
    var tocPopoverView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Contents")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 2) {
                    if book.isPDF {
                        if !pdfOutline.isEmpty {
                            ForEach(pdfOutline) { node in
                                Button(action: {
                                    targetPDFPage = node.pageIndex
                                    currentChapterIndex = node.pageIndex
                                    updateBookmarkState()
                                    showTOCPopover = false
                                }) {
                                    HStack {
                                        Text(node.title)
                                            .font(.system(size: 13, weight: currentChapterIndex == node.pageIndex ? .bold : .regular))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        Text("\(node.pageIndex + 1)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(currentChapterIndex == node.pageIndex ? Color.secondary.opacity(0.14) : Color.clear)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                                .focusEffectDisabled()
                            }
                        } else {
                            ForEach(0..<max(1, totalChapters), id: \.self) { idx in
                                Button(action: {
                                    targetPDFPage = idx
                                    currentChapterIndex = idx
                                    updateBookmarkState()
                                    showTOCPopover = false
                                }) {
                                    HStack {
                                        Text("Page \(idx + 1)")
                                            .font(.system(size: 13, weight: currentChapterIndex == idx ? .bold : .regular))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        Text("\(idx + 1)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(currentChapterIndex == idx ? Color.secondary.opacity(0.14) : Color.clear)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                                .focusEffectDisabled()
                            }
                        }
                    } else if !bookTOC.isEmpty {
                        ForEach(bookTOC) { entry in
                            let isSelected = currentChapterIndex == entry.chapterIndex
                            Button(action: {
                                currentChapterIndex = entry.chapterIndex
                                currentSpreadIndex = 1
                                seekToSpread = 1
                                loadChapter()
                                updateBookmarkState()
                                showTOCPopover = false
                            }) {
                                HStack(spacing: 6) {
                                    if entry.level > 0 {
                                        Spacer().frame(width: CGFloat(min(entry.level, 3) * 14))
                                    }
                                    Text(entry.title)
                                        .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    let scaledPage = max(1, Int(round(Double(entry.page) * dynamicScaleRatio)))
                                    Text("\(scaledPage)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(isSelected ? Color.secondary.opacity(0.14) : Color.clear)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .focusEffectDisabled()
                        }
                    } else {
                        ForEach(0..<max(1, totalChapters), id: \.self) { idx in
                            Button(action: {
                                currentChapterIndex = idx
                                currentSpreadIndex = 1
                                seekToSpread = 1
                                loadChapter()
                                updateBookmarkState()
                                showTOCPopover = false
                            }) {
                                HStack {
                                    Text("Chapter \(idx + 1)")
                                        .font(.system(size: 13, weight: currentChapterIndex == idx ? .bold : .regular))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text("\(idx + 1)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(currentChapterIndex == idx ? Color.secondary.opacity(0.14) : Color.clear)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .focusEffectDisabled()
                        }
                    }
                }
                .padding(8)
            }
            .frame(width: 320, height: 380)
        }
    }
    
    // 2. Bookmarks Popover (Screenshot m4Tiar)
    var bookmarksPopoverView: some View {
        VStack(spacing: 0) {
            Text("Bookmarks")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            if bookmarks.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Text("No Bookmarks")
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .foregroundColor(.primary)
                    Text("To bookmark a page, click the\nbookmark icon in the toolbar.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                    Spacer()
                }
                .padding(24)
                .frame(width: 260, height: 260)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(bookmarks) { bm in
                            HStack {
                                Button(action: {
                                    if book.isPDF {
                                        targetPDFPage = bm.chapterIndex
                                        currentChapterIndex = bm.chapterIndex
                                    } else {
                                        currentChapterIndex = bm.chapterIndex
                                        currentSpreadIndex = bm.spreadIndex
                                        seekToSpread = bm.spreadIndex
                                        loadChapter()
                                    }
                                    updateBookmarkState()
                                    showBookmarksPopover = false
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "bookmark.fill")
                                            .foregroundColor(Color(red: 0.95, green: 0.22, blue: 0.22))
                                            .font(.system(size: 12))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(bm.chapterTitle)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            Text("Page \(bm.pageNumber)")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                                .focusEffectDisabled()
                                
                                Button(action: {
                                    bookmarks.removeAll { $0.id == bm.id }
                                    let bookKey = book.path ?? book.title
                                    BookmarksStorage.shared.saveBookmarks(bookmarks, for: bookKey)
                                    updateBookmarkState()
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary.opacity(0.7))
                                        .padding(4)
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                                .focusEffectDisabled()
                                .help("Delete Bookmark")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(6)
                        }
                    }
                    .padding(8)
                }
                .frame(width: 270, height: 280)
            }
        }
    }
    
    // 3. Highlights & Notes Popover (Screenshot aSUZCS) - Squared Apple Books Notes Style
    var notesPopoverView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Highlights & Notes")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    showAddNoteSheet.toggle()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Circle().fill(Color.secondary.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help("Add Note to Current Page")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            if showAddNoteSheet {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Note (Page \(overallCurrentPage))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    if !selectedQuoteText.isEmpty {
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: 2.5)
                            Text("\"\(selectedQuoteText)\"")
                                .font(.system(size: 11, design: .serif))
                                .italic()
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 2)
                    }
                    
                    TextField("Write a note...", text: $newNoteText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(8)
                        .background(Color.secondary.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    
                    HStack {
                        Button("Cancel") {
                            newNoteText = ""
                            selectedQuoteText = ""
                            showAddNoteSheet = false
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Save") {
                            if !newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                addAnnotation(text: selectedQuoteText, note: newNoteText, colorHex: "#FFE270")
                                newNoteText = ""
                                selectedQuoteText = ""
                                showAddNoteSheet = false
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)))
                    }
                }
                .padding(12)
                .background(Color.secondary.opacity(0.05))
                .overlay(Rectangle().stroke(Color.secondary.opacity(0.15), lineWidth: 0.5))
            }
            
            if notes.isEmpty && !showAddNoteSheet {
                VStack(spacing: 10) {
                    Spacer()
                    Text("No Highlights or Notes")
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .foregroundColor(.primary)
                    Text("Select text with your cursor to\nhighlight or add a note.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                    Spacer()
                }
                .padding(24)
                .frame(width: 300, height: 280)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(notes) { n in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    // Squared Apple Color Note Chip
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: n.colorHex))
                                        .frame(width: 10, height: 10)
                                    
                                    Text(n.chapterTitle)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text("Page \(n.pageNumber)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: {
                                        deleteNote(id: n.id)
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete Note")
                                }
                                
                                if !n.text.isEmpty {
                                    HStack(spacing: 6) {
                                        Rectangle()
                                            .fill(Color(hex: n.colorHex))
                                            .frame(width: 2.5)
                                        Text("\"\(n.text)\"")
                                            .font(.system(size: 12, design: .serif))
                                            .italic()
                                            .foregroundColor(.secondary)
                                            .lineLimit(3)
                                    }
                                    .padding(.vertical, 2)
                                }
                                
                                if !n.note.isEmpty {
                                    // Squared Note Box matching Apple Books
                                    Text(n.note)
                                        .font(.system(size: 12))
                                        .foregroundColor(.primary)
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(hex: n.colorHex).opacity(0.12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color(hex: n.colorHex).opacity(0.35), lineWidth: 1)
                                        )
                                }
                            }
                            .padding(10)
                            .background(Color.primary.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                jumpToNote(n)
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(width: 320, height: 360)
            }
        }
    }
    
    // 4. Themes & Settings Popover (Screenshot hueuX4)
    var themesAndSettingsPopoverView: some View {
        VStack(spacing: 16) {
            Text("Themes & Settings")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
            
            // Top Row: Smaller A, Larger A, Appearance Toggle
            HStack(spacing: 0) {
                Button(action: {
                    if fontSize > 14 { fontSize -= 2 }
                }) {
                    Text("A")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()
                
                Divider().frame(height: 20)
                
                Button(action: {
                    if fontSize < 32 { fontSize += 2 }
                }) {
                    Text("A")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()
                
                Divider().frame(height: 20)
                
                Button(action: {
                    // Cycle day/night
                    if readerTheme == "Original" {
                        readerTheme = "Quiet"
                    } else if readerTheme == "Quiet" {
                        readerTheme = "Bold"
                    } else {
                        readerTheme = "Original"
                    }
                }) {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()
            }
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(10)
            
            // 6 Apple Themes Grid (Screenshot hueuX4)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(themePalettes, id: \.0) { theme in
                    Button(action: {
                        readerTheme = theme.0
                    }) {
                        VStack(spacing: 4) {
                            Text("Aa")
                                .font(.system(size: 18, weight: theme.0 == "Bold" ? .heavy : .medium, design: .serif))
                                .foregroundColor(theme.3)
                            Text(theme.1)
                                .font(.system(size: 10))
                                .foregroundColor(theme.3.opacity(0.8))
                        }
                        .frame(width: 72, height: 60)
                        .background(theme.2)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(readerTheme == theme.0 ? Color.primary : Color.secondary.opacity(0.2), lineWidth: readerTheme == theme.0 ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .focusEffectDisabled()
                }
            }
            
            // Customize Button with Gear Icon (Screenshot dt6lEi -> opens JQR9yt)
            Button(action: {
                showAppearancePopover = false
                showCustomizeSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                    Text("Customize")
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .focusEffectDisabled()
        }
        .padding(16)
        .frame(width: 270)
    }
    
    func isBookmarkForCurrentPage(_ bm: BookmarkItem) -> Bool {
        if book.isPDF {
            return bm.chapterIndex == currentChapterIndex || bm.pageNumber == overallCurrentPage
        } else {
            return bm.chapterIndex == currentChapterIndex && bm.spreadIndex == currentSpreadIndex
        }
    }
    
    func updateBookmarkState() {
        self.isBookmarked = bookmarks.contains { isBookmarkForCurrentPage($0) }
    }
    
    func toggleBookmark() {
        let bookKey = book.path ?? book.title
        if let idx = bookmarks.firstIndex(where: { isBookmarkForCurrentPage($0) }) {
            bookmarks.remove(at: idx)
            isBookmarked = false
        } else {
            let title: String
            if book.isPDF {
                title = "Page \(overallCurrentPage)"
            } else if let ch = bookTOC.first(where: { $0.chapterIndex == currentChapterIndex }) {
                title = ch.title
            } else if !chapterTitle.isEmpty {
                title = chapterTitle
            } else {
                title = "Chapter \(currentChapterIndex + 1)"
            }
            
            let item = BookmarkItem(
                id: UUID(),
                chapterIndex: currentChapterIndex,
                spreadIndex: currentSpreadIndex,
                chapterTitle: title,
                pageNumber: overallCurrentPage,
                date: Date()
            )
            bookmarks.append(item)
            isBookmarked = true
        }
        BookmarksStorage.shared.saveBookmarks(bookmarks, for: bookKey)
    }
    
    func deleteNote(id: UUID) {
        let bookKey = book.path ?? book.title
        notes.removeAll { $0.id == id }
        NotesStorage.shared.saveNotes(notes, for: bookKey)
    }
    
    func deleteAnnotationByText(_ text: String) {
        let bookKey = book.path ?? book.title
        notes.removeAll { $0.chapterIndex == currentChapterIndex && $0.text == text }
        NotesStorage.shared.saveNotes(notes, for: bookKey)
    }
    
    func jumpToNote(_ note: NoteItem) {
        if book.isPDF {
            targetPDFPage = note.chapterIndex
            currentChapterIndex = note.chapterIndex
        } else {
            currentChapterIndex = note.chapterIndex
            currentSpreadIndex = note.spreadIndex
            seekToSpread = note.spreadIndex
            loadChapter()
        }
        showNotesPopover = false
    }
    
    func addAnnotation(text: String, note: String, colorHex: String) {
        let bookKey = book.path ?? book.title
        let title: String
        if book.isPDF {
            title = "Page \(overallCurrentPage)"
        } else if let ch = bookTOC.first(where: { $0.chapterIndex == currentChapterIndex }) {
            title = ch.title
        } else {
            title = "Chapter \(currentChapterIndex + 1)"
        }
        let newNote = NoteItem(
            id: UUID(),
            text: text,
            note: note,
            colorHex: colorHex,
            chapterIndex: currentChapterIndex,
            spreadIndex: currentSpreadIndex,
            pageNumber: overallCurrentPage,
            chapterTitle: title,
            date: Date()
        )
        notes.insert(newNote, at: 0)
        NotesStorage.shared.saveNotes(notes, for: bookKey)
    }
    
    func loadMetadata() {
        guard let path = book.path else { return }
        let resolved = (path as NSString).expandingTildeInPath
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: ScriptResolver.pythonPath)
            p.arguments = [
                ScriptResolver.scriptPath(named: "epub_metadata.py"),
                resolved
            ]
            let pipe = Pipe()
            p.standardOutput = pipe
            try? p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let resp = try? JSONDecoder().decode(BookMetadataResponse.self, from: data) {
                DispatchQueue.main.async {
                    self.bookTOC = resp.chapters
                    self.estimatedTotalPages = max(1, resp.totalPages)
                    self.spineBasePages = resp.spinePages
                    var starts: [Int] = [1]
                    for pCount in resp.spinePages.dropLast() {
                        starts.append((starts.last ?? 1) + pCount)
                    }
                    self.spineStartPages = starts
                }
            }
        }
    }
    
    func loadChapter() {
        guard let path = book.path else { return }
        stopAudio()
        if book.isPDF {
            let resolved = (path as NSString).expandingTildeInPath
            if let doc = PDFDocument(url: URL(fileURLWithPath: resolved)) {
                DispatchQueue.main.async {
                    self.totalChapters = max(1, doc.pageCount)
                    self.pdfOutline = extractPDFOutline(from: doc)
                    self.isLoading = false
                    self.isInitialBookLoad = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.isInitialBookLoad = false
                }
            }
            return
        }
        if isInitialBookLoad {
            isLoading = true
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: ScriptResolver.pythonPath)
            p.arguments = [
                ScriptResolver.scriptPath(named: "read_chapter.py"),
                path,
                "\(self.currentChapterIndex)"
            ]
            let pipe = Pipe()
            p.standardOutput = pipe
            try? p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var firstTextIdx = 0
                if let ftRange = output.range(of: "FIRST_TEXT_INDEX:") {
                    let sub = output[ftRange.upperBound...]
                    if let endOfLine = sub.firstIndex(of: "\n"), let fIdx = Int(sub[..<endOfLine].trimmingCharacters(in: .whitespaces)) {
                        firstTextIdx = fIdx
                    }
                }
                
                if let countRange = output.range(of: "COUNT:") {
                    let sub = output[countRange.upperBound...]
                    if let endOfLine = sub.firstIndex(of: "\n"), let count = Int(sub[..<endOfLine].trimmingCharacters(in: .whitespaces)) {
                        DispatchQueue.main.async {
                            self.totalChapters = max(1, count)
                            self.firstTextChapter = firstTextIdx
                        }
                    }
                }
                
                var content = output
                if let r = output.range(of: "CONTENT_START\n") {
                    content = String(output[r.upperBound...])
                }
                
                DispatchQueue.main.async {
                    self.chapterContent = content
                    self.currentSpreadIndex = 1
                    self.isLoading = false
                    self.isInitialBookLoad = false
                    self.updateBookmarkState()
                }
            }
        }
    }
    
    func startReadingTimer() {
        readingTimer?.invalidate()
        lastTickTime = Date()
        lastActivityTime = Date()
        fractionalSeconds = 0.0
        
        // 5 Hz timer for instant responsiveness when switching windows
        readingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            DispatchQueue.main.async {
                // 1. Must be the active application
                guard NSApp.isActive else {
                    self.lastTickTime = nil
                    return
                }
                
                // 2. Must have the reader window as key and visible (halts immediately if switched to another window)
                guard let win = self.hostingWindow ?? NSApp.keyWindow,
                      win.isKeyWindow,
                      !win.isMiniaturized,
                      win.isVisible else {
                    self.lastTickTime = nil
                    return
                }
                
                let now = Date()
                guard let last = self.lastTickTime else {
                    // First tick after becoming active/key
                    self.lastTickTime = now
                    return
                }
                
                let delta = now.timeIntervalSince(last)
                self.lastTickTime = now
                
                // Discard large gaps (e.g. sleep or prolonged backgrounding)
                guard delta > 0 && delta < 2.0 else { return }
                
                // 3. Must be actively reading: either audio is playing or recent user activity (< 60s)
                let isRecentActivity = now.timeIntervalSince(self.lastActivityTime) < 60
                guard self.isPlayingAudio || isRecentActivity else { return }
                
                // Accumulate fractional seconds accurately
                self.fractionalSeconds += delta
                let wholeSeconds = Int(self.fractionalSeconds)
                if wholeSeconds >= 1 {
                    ReadingGoalsManager.shared.addSeconds(wholeSeconds)
                    self.fractionalSeconds -= Double(wholeSeconds)
                    self.activeReadingSeconds += wholeSeconds
                    
                    // Mark as currently reading after 15s of focused active reading
                    if !self.hasMarkedCurrentlyReading && self.activeReadingSeconds >= 15 {
                        self.hasMarkedCurrentlyReading = true
                        CurrentlyReadingManager.shared.markAsReading(book: self.book, chapterIndex: self.currentChapterIndex)
                    }
                }
            }
        }
    }
    
    func stopReadingTimer() {
        readingTimer?.invalidate()
        readingTimer = nil
        lastTickTime = nil
        fractionalSeconds = 0.0
    }
    
    func toggleAudio() {
        if isPlayingAudio {
            stopAudio()
        } else {
            startAudio()
        }
    }
    
    func startAudio() {
        guard let path = book.path else { return }
        
        // Terminate any previous process
        if let proc = ttsProcess, proc.isRunning {
            proc.terminate()
        }
        ttsProcess = nil
        
        isPlayingAudio = true
        showFloatingAudio = true
        
        let task = Process()
        let pyPath = ScriptResolver.pythonPath
        task.executableURL = URL(fileURLWithPath: pyPath)
        
        let chapToSpeak = currentChapterIndex
        let snippet = currentVisibleSnippet.trimmingCharacters(in: .whitespacesAndNewlines)
        task.arguments = [
            ScriptResolver.scriptPath(named: "speak_chapter.py"),
            path,
            "\(chapToSpeak)",
            selectedVoice,
            "\(readingSpeed)",
            snippet.isEmpty ? "__START__" : String(snippet.prefix(200))
        ]
        
        let cacheDir = ("~/.books1_cache" as NSString).expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
        let errLogPath = cacheDir + "/tts_error.log"
        FileManager.default.createFile(atPath: errLogPath, contents: nil)
        if let fileHandle = FileHandle(forWritingAtPath: errLogPath) {
            task.standardError = fileHandle
        }
        
        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                self.isPlayingAudio = false
            }
        }
        
        self.ttsProcess = task
        try? task.run()
    }
    
    func stopAudio() {
        isPlayingAudio = false
        if let proc = ttsProcess, proc.isRunning {
            proc.terminate()
        }
        ttsProcess = nil
        
        let pidFile = ("~/.books1_cache/tts.pid" as NSString).expandingTildeInPath
        if let pidStr = try? String(contentsOfFile: pidFile, encoding: .utf8),
           let pid = Int32(pidStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
            kill(pid, SIGTERM)
            try? FileManager.default.removeItem(atPath: pidFile)
        }
    }
    
    static func killGlobalAudio() {
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killTask.arguments = ["-9", "-f", "speak_chapter.py"]
        try? killTask.run()
        
        let pidFile = ("~/.books1_cache/tts.pid" as NSString).expandingTildeInPath
        if let pidStr = try? String(contentsOfFile: pidFile, encoding: .utf8),
           let pid = Int32(pidStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
            kill(pid, SIGKILL)
            try? FileManager.default.removeItem(atPath: pidFile)
        }
    }
}

//
// Native Apple Books "Customize Theme" Modal Sheet (Screenshot JQR9yt)
//
struct CustomizeThemeSheetView: View {
    @Binding var isPresented: Bool
    @Binding var selectedFontFamily: String
    @Binding var isBoldText: Bool
    @Binding var isCustomizeEnabled: Bool
    @Binding var readerTheme: String
    @Binding var lineSpacing: Double
    @Binding var characterSpacing: Double
    @Binding var wordSpacing: Double
    @Binding var marginScale: Double
    @Binding var columnsOption: String
    @Binding var justifyText: Bool
    let fontFamilies: [String]
    
    @State private var showingFontPicker: Bool = false
    
    private func fontDisplayName(_ f: String) -> String {
        if f == "-apple-system" || f == "San Francisco" {
            return "San Francisco"
        }
        return f
    }
    
    private var previewHeaderFont: Font {
        if selectedFontFamily == "San Francisco" || selectedFontFamily == "-apple-system" {
            return .system(size: 34, weight: isBoldText ? .black : .bold, design: .default)
        } else {
            return .system(size: 34, weight: isBoldText ? .heavy : .bold, design: .serif)
        }
    }
    
    private var previewBodyFont: Font {
        let weight: Font.Weight = isBoldText ? .semibold : .regular
        if selectedFontFamily == "San Francisco" || selectedFontFamily == "-apple-system" {
            return .system(size: 13.5, weight: weight, design: .default)
        } else if selectedFontFamily == "Original" {
            return .system(size: 13.5, weight: weight, design: .serif)
        } else {
            return .custom(selectedFontFamily, size: 13.5)
        }
    }
    
    private func fontForPreview(_ f: String, size: CGFloat) -> Font {
        if f == "San Francisco" || f == "-apple-system" {
            return .system(size: size, weight: .regular, design: .default)
        } else if f == "Original" {
            return .system(size: size, weight: .regular, design: .serif)
        } else {
            return .custom(f, size: size)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Nav Header Bar (Matching Screenshot JQR9yt)
            HStack {
                if showingFontPicker {
                    Button(action: { showingFontPicker = false }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                } else {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary.opacity(0.75))
                            .frame(width: 30, height: 30)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
                
                Spacer()
                
                Text(showingFontPicker ? "Font" : "Customize Theme")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if showingFontPicker {
                    Button(action: { showingFontPicker = false }) {
                        Text("Done")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                } else {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)
            
            if showingFontPicker {
                // Font Selection List
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(fontFamilies, id: \.self) { fontName in
                            Button(action: {
                                selectedFontFamily = fontName
                                showingFontPicker = false
                            }) {
                                HStack {
                                    Text(fontDisplayName(fontName))
                                        .font(fontForPreview(fontName, size: 15))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedFontFamily == fontName {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            if fontName != fontFamilies.last {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .cornerRadius(12)
                    .padding(20)
                }
            } else {
                // Top Live Typography Preview Card (Exact matching Screenshot JQR9yt)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Aa")
                        .font(previewHeaderFont)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    
                    Text("It is my opinion that lots would escape from slavery, who now remain, however for the strong cords of love that bind them to their friends. The idea of leaving my pals turned into decidedly the most painful concept with which I needed to contend. The love of them become my tender point, and shook my selection more than all matters else. Besides the pain of separation, the dread and apprehension of a failure handed what I had skilled at my first try. The appalling defeat I then sustained back to torment me. I felt confident that, if I failed in this attempt, my case could be a hopeless one—it might seal my fate as a slave all the time.")
                        .font(previewBodyFont)
                        .foregroundColor(.primary)
                        .lineSpacing(3.8)
                        .padding(.horizontal, 24)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0.0),
                                    .init(color: .black, location: 0.72),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .frame(height: 220, alignment: .topLeading)
                
                Divider()
                
                // Form Options matching Screenshot JQR9yt
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        // Section: Text
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Text")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.leading, 14)
                            
                            VStack(spacing: 0) {
                                // Font Row
                                Button(action: { showingFontPicker = true }) {
                                    HStack(spacing: 12) {
                                        Text("Aa")
                                            .font(.system(size: 15, weight: .semibold, design: .serif))
                                            .frame(width: 22)
                                        Text("Font")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(fontDisplayName(selectedFontFamily))
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary.opacity(0.6))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                Divider().padding(.leading, 48)
                                
                                // Bold Text Row
                                HStack(spacing: 12) {
                                    Text("B")
                                        .font(.system(size: 15, weight: .black, design: .serif))
                                        .frame(width: 22)
                                    Text("Bold Text")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Toggle("", isOn: $isBoldText)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                            }
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                            .cornerRadius(12)
                        }
                        
                        // Section: Layout
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Layout")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.leading, 14)
                            
                            VStack(spacing: 0) {
                                // Line Spacing
                                VStack(spacing: 4) {
                                    HStack {
                                        Image(systemName: "text.line.spacing")
                                            .font(.system(size: 13))
                                            .frame(width: 22)
                                        Text("Line Spacing")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(String(format: "%.2f", lineSpacing))
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                    }
                                    Slider(value: $lineSpacing, in: 1.0...3.0, step: 0.05)
                                        .controlSize(.small)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                
                                Divider().padding(.leading, 48)
                                
                                // Character Spacing
                                VStack(spacing: 4) {
                                    HStack {
                                        Image(systemName: "character.textbox")
                                            .font(.system(size: 13))
                                            .frame(width: 22)
                                        Text("Character Spacing")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(Int(characterSpacing))%")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                    }
                                    Slider(value: $characterSpacing, in: -5...15, step: 1)
                                        .controlSize(.small)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                
                                Divider().padding(.leading, 48)
                                
                                // Word Spacing
                                VStack(spacing: 4) {
                                    HStack {
                                        Image(systemName: "textformat.abc")
                                            .font(.system(size: 13))
                                            .frame(width: 22)
                                        Text("Word Spacing")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(Int(wordSpacing))%")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                    }
                                    Slider(value: $wordSpacing, in: -5...15, step: 1)
                                        .controlSize(.small)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                
                                Divider().padding(.leading, 48)
                                
                                // Margins
                                VStack(spacing: 4) {
                                    HStack {
                                        Image(systemName: "arrow.left.and.right")
                                            .font(.system(size: 13))
                                            .frame(width: 22)
                                        Text("Margins")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(Int(marginScale))%")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                    }
                                    Slider(value: $marginScale, in: 0...50, step: 5)
                                        .controlSize(.small)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                
                                Divider().padding(.leading, 48)
                                
                                // Columns
                                HStack(spacing: 12) {
                                    Image(systemName: "rectangle.split.2x1")
                                        .font(.system(size: 13))
                                        .frame(width: 22)
                                    Text("Columns")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Picker("", selection: $columnsOption) {
                                        Text("Auto").tag("auto")
                                        Text("1").tag("1")
                                        Text("2").tag("2")
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 140)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                
                                Divider().padding(.leading, 48)
                                
                                // Justify Text
                                HStack(spacing: 12) {
                                    Image(systemName: "text.justify.left")
                                        .font(.system(size: 13))
                                        .frame(width: 22)
                                    Text("Justify Text")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Toggle("", isOn: $justifyText)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                
                                Divider().padding(.leading, 48)
                                
                                // Customize toggle
                                HStack(spacing: 12) {
                                    Image(systemName: "paintbrush")
                                        .font(.system(size: 13))
                                        .frame(width: 22)
                                    Text("Customize")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Toggle("", isOn: $isCustomizeEnabled)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                            }
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                            .cornerRadius(12)
                        }
                        
                        // Section: Reset Theme Button
                        Button(action: {
                            selectedFontFamily = "Original"
                            isBoldText = false
                            isCustomizeEnabled = true
                            readerTheme = "Original"
                            lineSpacing = 1.74
                            characterSpacing = 0.0
                            wordSpacing = 0.0
                            marginScale = 0.0
                            columnsOption = "auto"
                            justifyText = true
                        }) {
                            Text("Reset Theme")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(width: 440, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

//
// Realistic Red Bookmark Ribbon Shape (Screenshot DcKW6y & f27b11)
//
struct BookmarkRibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 8))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

//
// WebKit Custom View to eliminate macOS Dictionary / Look Up XPC freezes and rainbow beachballs
//
class BookWKWebView: WKWebView {
    override func pressureChange(with event: NSEvent) {
        // Prevent Force Touch / Force Click Look Up dictionary freeze & rainbow beachball
    }
    
    override func quickLook(with event: NSEvent) {
        // Prevent QuickLook dictionary lookup hang
    }
    
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        // Remove Look Up, Search with, and Share system services that cause XPC beachballs in embedded WKWebView
        for item in menu.items {
            if item.title.contains("Look Up") || item.title.contains("Search with") || item.title.contains("Share") {
                item.isHidden = true
            }
        }
        super.willOpenMenu(menu, with: event)
    }
}

//
// WebKit Book View with Floating Annotation Suite, Live Window Resizing, and Smooth Page Turns
//
struct BookWebView: NSViewRepresentable {
    let htmlContent: String
    let isTwoPageSpread: Bool
    let readerTheme: String
    let fontSize: Double
    let fontFamily: String
    let isBoldText: Bool
    let isEditMode: Bool
    let pageNumber: Int
    let bookPath: String
    let chapterIndex: Int
    let savedAnnotations: [NoteItem]
    let triggerNextPage: Int
    let triggerPrevPage: Int
    let seekToSpread: Int
    let lineSpacing: Double
    let characterSpacing: Double
    let wordSpacing: Double
    let marginScale: Double
    let columnsOption: String
    let justifyText: Bool
    var onMouseActivity: (() -> Void)? = nil
    var onAddAnnotation: ((String, String, String) -> Void)? = nil
    var onPromptNote: ((String) -> Void)? = nil
    var onDeleteAnnotation: ((String) -> Void)? = nil
    var onVisibleSnippet: ((String) -> Void)? = nil
    let onPageMetrics: (Int, Int, Int) -> Void
    let onNextChapter: () -> Void
    let onPrevChapter: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: BookWebView
        var webView: BookWKWebView?
        var lastNextTrigger: Int = 0
        var lastPrevTrigger: Int = 0
        var lastSeekSpread: Int = 1
        var lastContentKey: String = ""
        var lastBoundsSize: CGSize = .zero
        
        init(_ parent: BookWebView) {
            self.parent = parent
            self.lastNextTrigger = parent.triggerNextPage
            self.lastPrevTrigger = parent.triggerPrevPage
            self.lastSeekSpread = parent.seekToSpread
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "pageNav" {
                if let action = message.body as? String {
                    if action == "nextChapter" {
                        DispatchQueue.main.async { self.parent.onNextChapter() }
                    } else if action == "prevChapter" {
                        DispatchQueue.main.async { self.parent.onPrevChapter() }
                    }
                }
            } else if message.name == "pageMetrics" {
                if let dict = message.body as? [String: Any],
                   let cur = dict["current"] as? Int,
                   let tot = dict["total"] as? Int,
                   let left = dict["left"] as? Int {
                    parent.onPageMetrics(cur, tot, left)
                }
            } else if message.name == "mouseActivity" {
                DispatchQueue.main.async {
                    self.parent.onMouseActivity?()
                }
            } else if message.name == "createAnnotation" {
                if let dict = message.body as? [String: Any],
                   let text = dict["text"] as? String,
                   let hex = dict["colorHex"] as? String {
                    let note = dict["note"] as? String ?? ""
                    parent.onAddAnnotation?(text, note, hex)
                }
            } else if message.name == "promptNote" {
                if let dict = message.body as? [String: Any],
                   let text = dict["text"] as? String {
                    parent.onPromptNote?(text)
                }
            } else if message.name == "deleteAnnotation" {
                if let text = message.body as? String {
                    parent.onDeleteAnnotation?(text)
                }
            } else if message.name == "saveContent" {
                if let editedHTML = message.body as? String {
                    self.saveEditedContent(editedHTML)
                }
            } else if message.name == "visibleSnippet" {
                if let snippet = message.body as? String {
                    DispatchQueue.main.async {
                        self.parent.onVisibleSnippet?(snippet)
                    }
                }
            }
        }
        
        @objc func viewFrameChanged(_ notification: Notification) {
            guard let wv = webView, wv.bounds.size.width > 50 else { return }
            wv.evaluateJavaScript("if (typeof handleResize === 'function') handleResize();")
        }
        
        func saveEditedContent(_ html: String) {
            let task = Process()
            let pyPath = ScriptResolver.pythonPath
            task.executableURL = URL(fileURLWithPath: pyPath)
            task.arguments = [
                ScriptResolver.scriptPath(named: "read_chapter.py"),
                "--save",
                parent.bookPath,
                "\(parent.chapterIndex)"
            ]
            let pipe = Pipe()
            task.standardInput = pipe
            try? task.run()
            if let d = html.data(using: .utf8) {
                pipe.fileHandleForWriting.write(d)
                try? pipe.fileHandleForWriting.close()
            }
        }
    }
    
    func makeNSView(context: Context) -> BookWKWebView {
        let config = WKWebViewConfiguration()
        let ucc = WKUserContentController()
        ucc.add(context.coordinator, name: "pageNav")
        ucc.add(context.coordinator, name: "pageMetrics")
        ucc.add(context.coordinator, name: "mouseActivity")
        ucc.add(context.coordinator, name: "saveContent")
        ucc.add(context.coordinator, name: "createAnnotation")
        ucc.add(context.coordinator, name: "promptNote")
        ucc.add(context.coordinator, name: "deleteAnnotation")
        ucc.add(context.coordinator, name: "visibleSnippet")
        config.userContentController = ucc
        
        let webView = BookWKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.postsFrameChangedNotifications = true
        context.coordinator.webView = webView
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.viewFrameChanged(_:)),
            name: NSView.frameDidChangeNotification,
            object: webView
        )
        
        return webView
    }
    
    func updateNSView(_ webView: BookWKWebView, context: Context) {
        // Check for manual button flips
        if context.coordinator.lastNextTrigger != triggerNextPage {
            context.coordinator.lastNextTrigger = triggerNextPage
            webView.evaluateJavaScript("nextSpread()")
        }
        if context.coordinator.lastPrevTrigger != triggerPrevPage {
            context.coordinator.lastPrevTrigger = triggerPrevPage
            webView.evaluateJavaScript("prevSpread()")
        }
        if context.coordinator.lastSeekSpread != seekToSpread {
            context.coordinator.lastSeekSpread = seekToSpread
            webView.evaluateJavaScript("goToSpread(\(seekToSpread))")
        }
        
        if context.coordinator.lastBoundsSize != webView.bounds.size && webView.bounds.size.width > 50 {
            context.coordinator.lastBoundsSize = webView.bounds.size
            webView.evaluateJavaScript("if (typeof handleResize === 'function') handleResize();")
        }
        
        let savedItems: [[String: String]] = savedAnnotations.map {
            ["text": $0.text, "note": $0.note, "colorHex": $0.colorHex]
        }
        let savedJSON: String
        if let data = try? JSONSerialization.data(withJSONObject: savedItems, options: []),
           let json = String(data: data, encoding: .utf8) {
            savedJSON = json
        } else {
            savedJSON = "[]"
        }
        
        let contentKey = "\(chapterIndex)_\(bookPath)_\(readerTheme)_\(fontSize)_\(fontFamily)_\(isBoldText)_\(isTwoPageSpread)_\(isEditMode)_\(htmlContent.hashValue)_\(savedJSON.hashValue)_\(lineSpacing)_\(characterSpacing)_\(wordSpacing)_\(marginScale)_\(columnsOption)_\(justifyText)"
        guard context.coordinator.lastContentKey != contentKey else {
            return
        }
        context.coordinator.lastContentKey = contentKey
        
        let bgColor: String
        let textColor: String
        
        switch readerTheme {
        case "Quiet":
            bgColor = "#2C2C2E"
            textColor = "#E5E5EA"
        case "Paper":
            bgColor = "#F5EFE6"
            textColor = "#3D2E1E"
        case "Bold":
            bgColor = "#000000"
            textColor = "#FFFFFF"
        case "Calm":
            bgColor = "#F8EFE4"
            textColor = "#3D2F24"
        case "Focus":
            bgColor = "#EAEAEA"
            textColor = "#1C1C1E"
        default: // Original
            bgColor = "#FFFFFF"
            textColor = "#1C1C1E"
        }
        
        let baseMarginX = isTwoPageSpread ? 48 : 80
        let extraMargin = Int(Double(baseMarginX) * marginScale / 100.0 * 3.0)
        let marginX = baseMarginX + extraMargin
        let gapX = marginX * 2
        let editAttr = isEditMode ? "contenteditable='true'" : "contenteditable='false'"
        
        let effectiveColCount: Int
        let effectiveTwoPage: Bool
        switch columnsOption {
        case "1":
            effectiveColCount = 1
            effectiveTwoPage = false
        case "2":
            effectiveColCount = 2
            effectiveTwoPage = true
        default: // "auto"
            effectiveColCount = isTwoPageSpread ? 2 : 1
            effectiveTwoPage = isTwoPageSpread
        }
        
        let cssFontFamily: String
        switch fontFamily {
        case "Original":
            cssFontFamily = "-apple-system-subheadline, \"Iowan Old Style\", \"Palatino\", Georgia, serif"
        case "San Francisco":
            cssFontFamily = "-apple-system, BlinkMacSystemFont, \"SF Pro Text\", sans-serif"
        case "New York":
            cssFontFamily = "-apple-system-subheadline, \"New York\", Georgia, serif"
        default:
            cssFontFamily = "\"\(fontFamily)\", serif"
        }
        
        let letterSpacingCSS = characterSpacing == 0 ? "normal" : "\(characterSpacing * 0.01)em"
        let wordSpacingCSS = wordSpacing == 0 ? "normal" : "\(wordSpacing * 0.04)em"
        let textAlignCSS = justifyText ? "justify" : "left"
        
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
            * {
                box-sizing: border-box;
            }
            html, body {
                height: 100%;
                margin: 0;
                padding: 0;
                overflow: hidden;
            }
            body {
                background-color: \(bgColor);
                color: \(textColor);
                font-family: \(cssFontFamily);
                font-size: \(fontSize)px;
                font-weight: \(isBoldText ? "600" : "400");
                line-height: \(lineSpacing);
                letter-spacing: \(letterSpacingCSS);
                word-spacing: \(wordSpacingCSS);
                text-align: \(textAlignCSS);
                -webkit-font-smoothing: antialiased;
                text-rendering: optimizeLegibility;
                user-select: text !important;
                -webkit-user-select: text !important;
            }
            ::selection {
                background: rgba(255, 214, 10, 0.35);
                color: inherit;
            }
            #book-columns {
                height: 100vh;
                max-height: 100vh;
                box-sizing: border-box;
                padding: 82px \(marginX)px 54px \(marginX)px;
                column-width: \(effectiveTwoPage ? "calc((100vw - \(gapX)px - \(marginX * 2)px) / 2)" : "calc(100vw - \(marginX * 2)px)");
                column-count: \(effectiveColCount);
                column-gap: \(gapX)px;
                column-fill: auto;
                width: 100vw;
                overflow: visible;
                position: relative;
                will-change: transform;
                transition: transform 0.82s cubic-bezier(0.16, 1, 0.3, 1);
            }
            /* No separation element between pages (User Request) */
            body::before {
                display: none !important;
            }
            img, svg, image {
                max-width: 78% !important;
                max-height: calc(100vh - 190px) !important;
                width: auto !important;
                height: auto !important;
                object-fit: contain !important;
                border-radius: 4px;
                box-shadow: none !important;
                display: block !important;
                margin: 10px auto !important;
                break-inside: avoid !important;
                -webkit-column-break-inside: avoid !important;
            }
            .epub-cover-container, .cover, .cover-page {
                break-inside: avoid !important;
                -webkit-column-break-inside: avoid !important;
                break-after: auto !important;
                -webkit-column-break-after: auto !important;
                page-break-after: auto !important;
                width: 100% !important;
                max-width: 100% !important;
                height: calc(100vh - 160px) !important;
                max-height: calc(100vh - 160px) !important;
                display: flex !important;
                justify-content: center !important;
                align-items: center !important;
                margin: 0 auto !important;
                text-align: center !important;
                overflow: hidden !important;
            }
            .epub-cover-img, .epub-cover-container img, img[alt*="cover" i] {
                max-height: calc(100vh - 180px) !important;
                max-width: 80% !important;
                width: auto !important;
                height: auto !important;
                object-fit: contain !important;
                border-radius: 6px !important;
                box-shadow: none !important;
                display: block !important;
                margin: auto !important;
                break-inside: avoid !important;
                -webkit-column-break-inside: avoid !important;
            }
            p {
                text-indent: 1.75em;
                margin-top: 0;
                margin-bottom: 0;
                font-weight: \(isBoldText ? "600" : "400");
                text-align: justify;
                text-justify: inter-word;
                hyphens: auto;
                -webkit-hyphens: auto;
                break-inside: auto;
                -webkit-column-break-inside: auto;
            }
            h1, h2, h3, h4, h5, h6 {
                text-indent: 0;
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                font-weight: 700;
                text-align: center;
                margin-top: 1.2em;
                margin-bottom: 0.8em;
                break-after: avoid;
                -webkit-column-break-after: avoid;
            }
            h1 + p, h2 + p, h3 + p, h4 + p, .chapter-title + p {
                text-indent: 0;
            }
            blockquote {
                margin: 1.2em 2em;
                font-style: italic;
                opacity: 0.9;
                break-inside: avoid;
                -webkit-column-break-inside: avoid;
            }
            /* Invisible Margin Click Targets */
            .nav-strip-left {
                position: fixed;
                left: 0;
                top: 0;
                bottom: 0;
                width: \(marginX)px;
                cursor: pointer;
                z-index: 5;
            }
            .nav-strip-right {
                position: fixed;
                right: 0;
                top: 0;
                bottom: 0;
                width: \(marginX)px;
                cursor: pointer;
                z-index: 5;
            }
            
            /* Floating Apple Books Annotation Suite */
            #booksy-annotation-bar {
                position: fixed;
                z-index: 99999;
                display: none;
                align-items: center;
                gap: 7px;
                padding: 6px 11px;
                background: rgba(45, 45, 48, 0.88);
                backdrop-filter: blur(20px);
                -webkit-backdrop-filter: blur(20px);
                border-radius: 20px;
                box-shadow: 0 8px 24px rgba(0, 0, 0, 0.28), 0 0 0 0.5px rgba(255, 255, 255, 0.18);
                transform: translateX(-50%) scale(0.95);
                transition: opacity 0.15s ease, transform 0.15s ease;
                opacity: 0;
                pointer-events: none;
                user-select: none;
                -webkit-user-select: none;
            }
            #booksy-annotation-bar.visible {
                display: flex !important;
                opacity: 1;
                pointer-events: auto;
                transform: translateX(-50%) scale(1.0);
            }
            .booksy-color-chip {
                width: 17px;
                height: 17px;
                border-radius: 50%;
                cursor: pointer;
                transition: transform 0.12s ease;
                border: 1.5px solid rgba(255, 255, 255, 0.3);
                flex-shrink: 0;
            }
            .booksy-color-chip:hover {
                transform: scale(1.22);
            }
            .chip-yellow { background-color: #FFE270; }
            .chip-green { background-color: #A8F596; }
            .chip-blue { background-color: #92D6FF; }
            .chip-pink { background-color: #FFB3D9; }
            .chip-purple { background-color: #D2B4FF; }
            
            .booksy-divider {
                width: 1px;
                height: 15px;
                background: rgba(255, 255, 255, 0.22);
                margin: 0 2px;
            }
            .booksy-tool-btn {
                background: transparent;
                border: none;
                color: #FFFFFF;
                display: inline-flex;
                align-items: center;
                cursor: pointer;
                padding: 3px 6px;
                border-radius: 6px;
                transition: background 0.12s ease;
                font-size: 11.5px;
                font-weight: 500;
            }
            .booksy-tool-btn:hover {
                background: rgba(255, 255, 255, 0.18);
            }
            
            /* Highlight Marks in Body */
            mark.booksy-highlight {
                background-color: #FFE270;
                color: inherit;
                border-radius: 3px;
                padding: 1px 2px;
                cursor: pointer;
                mix-blend-mode: multiply;
            }
            body[style*="background-color: #000000"] mark.booksy-highlight,
            body[style*="background-color: #2C2C2E"] mark.booksy-highlight {
                mix-blend-mode: screen;
                opacity: 0.88;
            }
            span.booksy-underline {
                text-decoration: underline;
                text-decoration-color: #FF9500;
                text-decoration-thickness: 2.5px;
                cursor: pointer;
            }
        </style>
        </head>
        <body id="book-body" class="\(isEditMode ? "edit-active" : "")">
            <div class="nav-strip-left" onclick="prevSpread()"></div>
            <div class="nav-strip-right" onclick="nextSpread()"></div>
            
            <div id="booksy-annotation-bar">
                <div class="booksy-color-chip chip-yellow" title="Yellow" onclick="applyHighlight('#FFE270')"></div>
                <div class="booksy-color-chip chip-green" title="Green" onclick="applyHighlight('#A8F596')"></div>
                <div class="booksy-color-chip chip-blue" title="Blue" onclick="applyHighlight('#92D6FF')"></div>
                <div class="booksy-color-chip chip-pink" title="Pink" onclick="applyHighlight('#FFB3D9')"></div>
                <div class="booksy-color-chip chip-purple" title="Purple" onclick="applyHighlight('#D2B4FF')"></div>
                <div class="booksy-divider"></div>
                <button class="booksy-tool-btn" title="Underline" onclick="applyUnderline()">
                    <span style="text-decoration: underline; font-weight: bold; font-family: serif; font-size: 13px;">U</span>
                </button>
                <button class="booksy-tool-btn" title="Add Note" onclick="promptAddNote()">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"></path><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"></path></svg>
                    <span style="margin-left: 4px;">Note</span>
                </button>
                <button id="booksy-delete-btn" class="booksy-tool-btn" title="Delete Highlight" style="display: none;" onclick="deleteActiveHighlight()">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path></svg>
                </button>
            </div>
            
            <div id="book-columns" \(editAttr)>
                \(htmlContent)
            </div>
            
            <script>
                let currentSpread = 0;
                let isTurningPage = false;
                const columnsEl = document.getElementById('book-columns');
                const savedHighlights = \(savedJSON);
                
                function getSpreadWidth() {
                    return window.innerWidth;
                }
                
                function getTotalSpreads() {
                    const w = getSpreadWidth();
                    if (!columnsEl || w <= 0) return 1;
                    if (document.querySelector('.epub-cover-container') && !document.querySelector('p')) {
                        return 1;
                    }
                    return Math.max(1, Math.ceil((columnsEl.scrollWidth - 10) / w));
                }
                
                function reportMetrics() {
                    const total = getTotalSpreads();
                    const cur = currentSpread + 1;
                    const left = Math.max(0, total - cur);
                    if (window.webkit && window.webkit.messageHandlers.pageMetrics) {
                        window.webkit.messageHandlers.pageMetrics.postMessage({
                            current: cur,
                            total: total,
                            left: left
                        });
                    }
                    postVisibleSnippet();
                }
                
                function postVisibleSnippet() {
                    try {
                        var viewLeft = currentSpread * getSpreadWidth();
                        var viewRight = viewLeft + getSpreadWidth();
                        var allEls = columnsEl.querySelectorAll('p, h1, h2, h3, h4, h5, h6, li, td, blockquote, span, div');
                        var snippet = '';
                        for (var i = 0; i < allEls.length && snippet.length < 200; i++) {
                            var rect = allEls[i].getBoundingClientRect();
                            var elLeft = rect.left + window.scrollX + viewLeft;
                            if (rect.width > 0 && rect.left >= -10 && rect.left < getSpreadWidth() + 10) {
                                var text = allEls[i].innerText || '';
                                if (text.trim().length > 3) {
                                    snippet += text.trim() + ' ';
                                }
                            }
                        }
                        snippet = snippet.substring(0, 200).trim();
                        if (snippet.length > 0 && window.webkit && window.webkit.messageHandlers.visibleSnippet) {
                            window.webkit.messageHandlers.visibleSnippet.postMessage(snippet);
                        }
                    } catch(e) {}
                }
                
                function updateDisplay() {
                    columnsEl.style.transform = 'translateX(' + (-currentSpread * getSpreadWidth()) + 'px)';
                    reportMetrics();
                }
                
                function nextSpread() {
                    if (isTurningPage) return;
                    hideAnnotationBar();
                    const total = getTotalSpreads();
                    if (currentSpread < total - 1) {
                        isTurningPage = true;
                        currentSpread++;
                        updateDisplay();
                        setTimeout(function() { isTurningPage = false; }, 820);
                    } else {
                        if (window.webkit && window.webkit.messageHandlers.pageNav) {
                            window.webkit.messageHandlers.pageNav.postMessage("nextChapter");
                        }
                    }
                }
                
                function prevSpread() {
                    if (isTurningPage) return;
                    hideAnnotationBar();
                    if (currentSpread > 0) {
                        isTurningPage = true;
                        currentSpread--;
                        updateDisplay();
                        setTimeout(function() { isTurningPage = false; }, 820);
                    } else {
                        if (window.webkit && window.webkit.messageHandlers.pageNav) {
                            window.webkit.messageHandlers.pageNav.postMessage("prevChapter");
                        }
                    }
                }
                
                function goToSpread(target) {
                    hideAnnotationBar();
                    const total = getTotalSpreads();
                    currentSpread = Math.max(0, Math.min(total - 1, target - 1));
                    updateDisplay();
                }
                
                //
                // Annotation Suite Actions & Positioning
                //
                let activeTargetHighlight = null;
                
                function showAnnotationBarAt(rect, isExisting) {
                    const bar = document.getElementById('booksy-annotation-bar');
                    if (!bar) return;
                    
                    const delBtn = document.getElementById('booksy-delete-btn');
                    if (delBtn) delBtn.style.display = isExisting ? 'inline-flex' : 'none';
                    
                    const midX = Math.max(140, Math.min(window.innerWidth - 140, rect.left + rect.width / 2));
                    let topY = rect.top - 46;
                    if (topY < 24) {
                        topY = rect.bottom + 12;
                    }
                    
                    bar.style.left = midX + 'px';
                    bar.style.top = topY + 'px';
                    bar.classList.add('visible');
                }
                
                function hideAnnotationBar() {
                    const bar = document.getElementById('booksy-annotation-bar');
                    if (bar) {
                        bar.classList.remove('visible');
                    }
                    activeTargetHighlight = null;
                }
                
                function showAnnotationBarForSelection(sel) {
                    if (!sel || sel.rangeCount === 0) return;
                    const range = sel.getRangeAt(0);
                    const rect = range.getBoundingClientRect();
                    if (rect.width === 0 && rect.height === 0) return;
                    activeTargetHighlight = null;
                    showAnnotationBarAt(rect, false);
                }
                
                function showHighlightActions(mark) {
                    const rect = mark.getBoundingClientRect();
                    activeTargetHighlight = mark;
                    showAnnotationBarAt(rect, true);
                }
                
                function applyHighlight(colorHex) {
                    if (activeTargetHighlight) {
                        activeTargetHighlight.style.backgroundColor = colorHex;
                        activeTargetHighlight.style.textDecoration = 'none';
                        activeTargetHighlight.setAttribute('data-color', colorHex);
                        const text = activeTargetHighlight.getAttribute('data-text') || activeTargetHighlight.textContent;
                        hideAnnotationBar();
                        if (window.webkit && window.webkit.messageHandlers.createAnnotation) {
                            window.webkit.messageHandlers.createAnnotation.postMessage({
                                text: text,
                                colorHex: colorHex,
                                note: ""
                            });
                        }
                        return;
                    }
                    
                    const sel = window.getSelection();
                    if (!sel || sel.rangeCount === 0) return;
                    const range = sel.getRangeAt(0);
                    const selectedText = sel.toString().trim();
                    if (!selectedText) return;
                    
                    try {
                        const mark = document.createElement('mark');
                        mark.className = 'booksy-highlight';
                        mark.setAttribute('data-color', colorHex);
                        mark.setAttribute('data-text', selectedText);
                        mark.style.backgroundColor = colorHex;
                        mark.addEventListener('click', function(e) {
                            e.stopPropagation();
                            showHighlightActions(mark);
                        });
                        
                        const fragment = range.extractContents();
                        mark.appendChild(fragment);
                        range.insertNode(mark);
                        
                        sel.removeAllRanges();
                        hideAnnotationBar();
                        
                        if (window.webkit && window.webkit.messageHandlers.createAnnotation) {
                            window.webkit.messageHandlers.createAnnotation.postMessage({
                                text: selectedText,
                                colorHex: colorHex,
                                note: ""
                            });
                        }
                    } catch(err) {
                        console.error("Highlight error:", err);
                    }
                }
                
                function applyUnderline() {
                    if (activeTargetHighlight) {
                        activeTargetHighlight.style.backgroundColor = 'transparent';
                        activeTargetHighlight.style.textDecoration = 'underline';
                        activeTargetHighlight.style.textDecorationColor = '#FF9500';
                        activeTargetHighlight.style.textDecorationThickness = '2.5px';
                        activeTargetHighlight.setAttribute('data-color', '#FF9500');
                        const text = activeTargetHighlight.getAttribute('data-text') || activeTargetHighlight.textContent;
                        hideAnnotationBar();
                        if (window.webkit && window.webkit.messageHandlers.createAnnotation) {
                            window.webkit.messageHandlers.createAnnotation.postMessage({
                                text: text,
                                colorHex: '#FF9500',
                                note: ""
                            });
                        }
                        return;
                    }
                    
                    const sel = window.getSelection();
                    if (!sel || sel.rangeCount === 0) return;
                    const range = sel.getRangeAt(0);
                    const selectedText = sel.toString().trim();
                    if (!selectedText) return;
                    
                    try {
                        const span = document.createElement('span');
                        span.className = 'booksy-underline';
                        span.setAttribute('data-color', '#FF9500');
                        span.setAttribute('data-text', selectedText);
                        span.style.textDecoration = 'underline';
                        span.style.textDecorationColor = '#FF9500';
                        span.style.textDecorationThickness = '2.5px';
                        span.style.cursor = 'pointer';
                        span.addEventListener('click', function(e) {
                            e.stopPropagation();
                            showHighlightActions(span);
                        });
                        
                        const fragment = range.extractContents();
                        span.appendChild(fragment);
                        range.insertNode(span);
                        
                        sel.removeAllRanges();
                        hideAnnotationBar();
                        
                        if (window.webkit && window.webkit.messageHandlers.createAnnotation) {
                            window.webkit.messageHandlers.createAnnotation.postMessage({
                                text: selectedText,
                                colorHex: '#FF9500',
                                note: ""
                            });
                        }
                    } catch(err) {
                        console.error("Underline error:", err);
                    }
                }
                
                function promptAddNote() {
                    let textToNote = "";
                    if (activeTargetHighlight) {
                        textToNote = activeTargetHighlight.getAttribute('data-text') || activeTargetHighlight.textContent;
                    } else {
                        const sel = window.getSelection();
                        if (sel && sel.rangeCount > 0) {
                            textToNote = sel.toString().trim();
                            applyHighlight('#FFE270');
                        }
                    }
                    hideAnnotationBar();
                    if (textToNote && window.webkit && window.webkit.messageHandlers.promptNote) {
                        window.webkit.messageHandlers.promptNote.postMessage({
                            text: textToNote,
                            colorHex: '#FFE270'
                        });
                    }
                }
                
                function deleteActiveHighlight() {
                    if (!activeTargetHighlight) return;
                    const text = activeTargetHighlight.getAttribute('data-text') || activeTargetHighlight.textContent;
                    const parent = activeTargetHighlight.parentNode;
                    if (parent) {
                        while (activeTargetHighlight.firstChild) {
                            parent.insertBefore(activeTargetHighlight.firstChild, activeTargetHighlight);
                        }
                        parent.removeChild(activeTargetHighlight);
                    }
                    hideAnnotationBar();
                    if (window.webkit && window.webkit.messageHandlers.deleteAnnotation) {
                        window.webkit.messageHandlers.deleteAnnotation.postMessage(text);
                    }
                }
                
                function highlightTextInNode(node, searchText, colorHex, note) {
                    if (node.nodeType === 3) { // Text node
                        const idx = node.nodeValue.indexOf(searchText);
                        if (idx !== -1) {
                            try {
                                const range = document.createRange();
                                range.setStart(node, idx);
                                range.setEnd(node, idx + searchText.length);
                                const mark = document.createElement(colorHex === '#FF9500' ? 'span' : 'mark');
                                mark.className = colorHex === '#FF9500' ? 'booksy-underline' : 'booksy-highlight';
                                mark.setAttribute('data-color', colorHex);
                                mark.setAttribute('data-text', searchText);
                                if (colorHex === '#FF9500') {
                                    mark.style.textDecoration = 'underline';
                                    mark.style.textDecorationColor = '#FF9500';
                                    mark.style.textDecorationThickness = '2.5px';
                                    mark.style.cursor = 'pointer';
                                } else {
                                    mark.style.backgroundColor = colorHex;
                                    mark.style.borderRadius = '3px';
                                    mark.style.padding = '1px 2px';
                                    mark.style.cursor = 'pointer';
                                }
                                if (note) mark.setAttribute('title', note);
                                mark.addEventListener('click', function(e) {
                                    e.stopPropagation();
                                    showHighlightActions(mark);
                                });
                                range.surroundContents(mark);
                                return true;
                            } catch(e) {
                                return false;
                            }
                        }
                    } else if (node.nodeType === 1 && node.childNodes && !['SCRIPT', 'STYLE', 'MARK', 'BUTTON'].includes(node.tagName) && node.id !== 'booksy-annotation-bar') {
                        for (let i = 0; i < node.childNodes.length; i++) {
                            if (highlightTextInNode(node.childNodes[i], searchText, colorHex, note)) {
                                return true;
                            }
                        }
                    }
                    return false;
                }
                
                function applySavedHighlights(highlights) {
                    if (!highlights || !highlights.length) return;
                    const root = document.getElementById('book-columns');
                    if (!root) return;
                    highlights.forEach(function(item) {
                        if (!item.text || item.text.trim().length < 2) return;
                        highlightTextInNode(root, item.text.trim(), item.colorHex || '#FFE270', item.note || '');
                    });
                }
                
                // Show floating bar on mouseup text selection
                document.addEventListener('mouseup', function(e) {
                    if (e.target.closest('#booksy-annotation-bar')) return;
                    setTimeout(function() {
                        const sel = window.getSelection();
                        if (sel && sel.toString().trim().length > 0) {
                            showAnnotationBarForSelection(sel);
                        } else if (!activeTargetHighlight) {
                            hideAnnotationBar();
                        }
                    }, 25);
                });
                
                // Intercept contextmenu to prevent macOS dictionary hang and show annotation bar
                window.addEventListener('contextmenu', function(e) {
                    const sel = window.getSelection();
                    if (sel && sel.toString().trim().length > 0) {
                        e.preventDefault();
                        showAnnotationBarForSelection(sel);
                    } else if (e.target.closest('.booksy-highlight') || e.target.closest('.booksy-underline')) {
                        e.preventDefault();
                        showHighlightActions(e.target.closest('.booksy-highlight') || e.target.closest('.booksy-underline'));
                    }
                });
                
                // Dismiss bar on outside click
                document.addEventListener('mousedown', function(e) {
                    if (!e.target.closest('#booksy-annotation-bar') && !e.target.closest('.booksy-highlight') && !e.target.closest('.booksy-underline')) {
                        const sel = window.getSelection();
                        if (!sel || sel.toString().trim().length === 0) {
                            hideAnnotationBar();
                        }
                    }
                });
                
                // Mouse Activity Reporter to auto-show/hide controls
                let lastActivityTime = 0;
                function reportActivity() {
                    const now = Date.now();
                    if (now - lastActivityTime > 180) {
                        lastActivityTime = now;
                        if (window.webkit && window.webkit.messageHandlers.mouseActivity) {
                            window.webkit.messageHandlers.mouseActivity.postMessage("active");
                        }
                    }
                }
                window.addEventListener('mousemove', reportActivity, { passive: true });
                window.addEventListener('mousedown', reportActivity, { passive: true });
                
                // Trackpad Two-Finger Swipe & Mouse Wheel Page Scrolling (Smoother & Slower)
                let wheelDeltaAcc = 0;
                let wheelLocked = false;
                let wheelResetTimer = null;
                
                window.addEventListener('wheel', function(e) {
                    e.preventDefault();
                    reportActivity();
                    
                    if (wheelLocked || isTurningPage) return;
                    
                    const delta = Math.abs(e.deltaX) > Math.abs(e.deltaY) ? e.deltaX : e.deltaY;
                    wheelDeltaAcc += delta;
                    
                    clearTimeout(wheelResetTimer);
                    wheelResetTimer = setTimeout(function() {
                        wheelDeltaAcc = 0;
                    }, 180);
                    
                    const THRESHOLD = 75;
                    if (wheelDeltaAcc >= THRESHOLD) {
                        wheelLocked = true;
                        wheelDeltaAcc = 0;
                        nextSpread();
                        setTimeout(function() { wheelLocked = false; }, 820);
                    } else if (wheelDeltaAcc <= -THRESHOLD) {
                        wheelLocked = true;
                        wheelDeltaAcc = 0;
                        prevSpread();
                        setTimeout(function() { wheelLocked = false; }, 820);
                    }
                }, { passive: false });
                
                // Keyboard Arrow Listeners
                window.addEventListener('keydown', function(e) {
                    reportActivity();
                    if (e.key === 'ArrowRight' || e.key === 'ArrowDown' || e.key === 'PageDown' || e.key === ' ') {
                        e.preventDefault();
                        nextSpread();
                    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp' || e.key === 'PageUp') {
                        e.preventDefault();
                        prevSpread();
                    }
                });
                
                // Continuous Dynamic Page Calculation on Window Resizing
                function handleResize() {
                    const totalNow = getTotalSpreads();
                    currentSpread = Math.max(0, Math.min(totalNow - 1, currentSpread));
                    columnsEl.style.transform = 'translateX(' + (-currentSpread * getSpreadWidth()) + 'px)';
                    reportMetrics();
                }
                window.addEventListener('resize', handleResize);
                
                if (window.ResizeObserver && columnsEl) {
                    const ro = new ResizeObserver(function() {
                        handleResize();
                    });
                    ro.observe(document.body);
                    ro.observe(columnsEl);
                }
                
                setTimeout(function() {
                    reportMetrics();
                    applySavedHighlights(savedHighlights);
                }, 80);
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(styledHTML, baseURL: URL(fileURLWithPath: bookPath))
    }
}

// Hex color extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
