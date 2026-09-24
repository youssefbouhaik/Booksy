//
//  EmbeddedReaderView.swift
//  Folio / Books
//
//  Apple Books HIG Pixel-Perfect Implementation
//

import SwiftUI
import WebKit
import PDFKit

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
    @State private var activeSpokenSentence: String = ""
    @State private var userRequestedStop: Bool = false
    
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
                    activeSpokenSentence: activeSpokenSentence,
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
                            CurrentlyReadingManager.shared.markAsReading(book: self.book, chapterIndex: self.currentChapterIndex, spreadIndex: cur)
                        }
                    },
                    onNextChapter: {
                        if currentChapterIndex < totalChapters - 1 {
                            currentChapterIndex += 1
                            currentSpreadIndex = 1
                            seekToSpread = 1
                            loadChapter()
                            updateBookmarkState()
                            CurrentlyReadingManager.shared.markAsReading(book: self.book, chapterIndex: self.currentChapterIndex, spreadIndex: 1)
                        }
                    },
                    onPrevChapter: {
                        if currentChapterIndex > 0 {
                            currentChapterIndex -= 1
                            currentSpreadIndex = 1
                            seekToSpread = 1
                            loadChapter()
                            updateBookmarkState()
                            CurrentlyReadingManager.shared.markAsReading(book: self.book, chapterIndex: self.currentChapterIndex, spreadIndex: 1)
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
            
            // Restore persistent reading position across sessions
            if let saved = CurrentlyReadingManager.shared.getSavedProgress(for: book) {
                self.currentChapterIndex = saved.chapter
                self.currentSpreadIndex = saved.spread
                self.seekToSpread = saved.spread
            }
            
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
            CurrentlyReadingManager.shared.markAsReading(book: self.book, chapterIndex: self.currentChapterIndex, spreadIndex: self.currentSpreadIndex)
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
        
        userRequestedStop = false
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
        
        // JSON-over-stdin IPC protocol
        task.arguments = [
            ScriptResolver.scriptPath(named: "speak_chapter.py"),
            "--json"
        ]
        
        let inPipe = Pipe()
        let outPipe = Pipe()
        task.standardInput = inPipe
        task.standardOutput = outPipe
        
        let cacheDir = ("~/.books1_cache" as NSString).expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
        let errLogPath = cacheDir + "/tts_error.log"
        FileManager.default.createFile(atPath: errLogPath, contents: nil)
        if let fileHandle = FileHandle(forWritingAtPath: errLogPath) {
            task.standardError = fileHandle
        }
        
        // Stream sentence-level progress events to synchronize reading highlight
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
            let lines = output.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasPrefix("{") && trimmed.hasSuffix("}"),
                      let lineData = trimmed.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      let event = json["event"] as? String, event == "sentence_start",
                      let text = json["text"] as? String else { continue }
                DispatchQueue.main.async {
                    self.activeSpokenSentence = text
                }
            }
        }
        
        task.terminationHandler = { proc in
            DispatchQueue.main.async {
                self.isPlayingAudio = false
                self.activeSpokenSentence = ""
                
                // Smarter chapter-boundary TTS: auto-advance across chapters without manual restart
                if !self.userRequestedStop && proc.terminationStatus == 0 {
                    if self.currentChapterIndex < self.totalChapters - 1 {
                        self.currentChapterIndex += 1
                        self.currentSpreadIndex = 1
                        self.seekToSpread = 1
                        self.currentVisibleSnippet = "__START__"
                        self.loadChapter()
                        self.startAudio()
                    }
                }
            }
        }
        
        self.ttsProcess = task
        try? task.run()
        
        // Send JSON payload over stdin
        let payload: [String: Any] = [
            "path": path,
            "chapter_index": chapToSpeak,
            "voice": selectedVoice,
            "speed": readingSpeed,
            "start_snippet": snippet.isEmpty ? "__START__" : String(snippet.prefix(200))
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: payload) {
            inPipe.fileHandleForWriting.write(jsonData)
            try? inPipe.fileHandleForWriting.close()
        }
    }
    
    func stopAudio() {
        userRequestedStop = true
        isPlayingAudio = false
        activeSpokenSentence = ""
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

