//
//  NativePDFKitView.swift
//  Folio / Books
//
//  PDFKit reader view with custom right-click annotations, multi-color highlights,
//  theme-aware background, multi-page layout modes, zoom controls, and thumbnail sidebar.
//

import SwiftUI
import AppKit
import PDFKit

// MARK: - Floating PDF Annotation Bar HUD
class PDFAnnotationBarView: NSVisualEffectView {
    var onColor: ((String, NSColor) -> Void)?
    var onUnderline: (() -> Void)?
    var onStrike: (() -> Void)?
    var onNote: (() -> Void)?
    var onCopy: (() -> Void)?
    var onDelete: (() -> Void)?
    
    private var deleteButton: NSButton?
    
    let palette: [(name: String, hex: String, color: NSColor)] = [
        ("Yellow", "#FFE270", NSColor(srgbRed: 1.0, green: 0.886, blue: 0.439, alpha: 0.65)),
        ("Green", "#A8F596", NSColor(srgbRed: 0.659, green: 0.961, blue: 0.588, alpha: 0.65)),
        ("Blue", "#92D6FF", NSColor(srgbRed: 0.573, green: 0.839, blue: 1.0, alpha: 0.65)),
        ("Pink", "#FFB3D9", NSColor(srgbRed: 1.0, green: 0.702, blue: 0.851, alpha: 0.65)),
        ("Purple", "#D2B4FF", NSColor(srgbRed: 0.824, green: 0.706, blue: 1.0, alpha: 0.65))
    ]
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 285, height: 36))
        self.material = .hudWindow
        self.state = .active
        self.blendingMode = .withinWindow
        self.wantsLayer = true
        self.layer?.cornerRadius = 18
        self.layer?.masksToBounds = true
        self.shadow = NSShadow()
        self.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.28)
        self.shadow?.shadowBlurRadius = 12
        self.shadow?.shadowOffset = NSSize(width: 0, height: -3)
        self.isHidden = true
        
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setHasActiveAnnotation(_ hasActive: Bool) {
        deleteButton?.isHidden = !hasActive
        let w: CGFloat = hasActive ? 320 : 285
        var f = self.frame
        f.size.width = w
        self.frame = f
    }
    
    private func setupViews() {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 7
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // 5 Color Circles
        for item in palette {
            let btn = NSButton(frame: NSRect(x: 0, y: 0, width: 18, height: 18))
            btn.title = ""
            btn.bezelStyle = .circular
            btn.isBordered = false
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 9
            btn.layer?.masksToBounds = true
            btn.layer?.backgroundColor = item.color.cgColor
            btn.layer?.borderWidth = 1.0
            btn.layer?.borderColor = NSColor.white.withAlphaComponent(0.4).cgColor
            btn.target = self
            btn.action = #selector(colorClicked(_:))
            btn.toolTip = "\(item.name) Highlight"
            btn.widthAnchor.constraint(equalToConstant: 18).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 18).isActive = true
            stack.addArrangedSubview(btn)
        }
        
        // Divider
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.widthAnchor.constraint(equalToConstant: 1).isActive = true
        sep.heightAnchor.constraint(equalToConstant: 16).isActive = true
        stack.addArrangedSubview(sep)
        
        // Underline
        let uBtn = makeToolButton(title: "U", font: NSFont.boldSystemFont(ofSize: 12), toolTip: "Underline", action: #selector(underlineClicked))
        stack.addArrangedSubview(uBtn)
        
        // Strike
        let sBtn = makeToolButton(title: "S", font: NSFont.boldSystemFont(ofSize: 12), toolTip: "Strikethrough", action: #selector(strikeClicked))
        stack.addArrangedSubview(sBtn)
        
        // Note
        let noteImg = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "Add Note")
        let noteBtn = makeIconButton(image: noteImg, toolTip: "Add / Edit Note", action: #selector(noteClicked))
        stack.addArrangedSubview(noteBtn)
        
        // Copy
        let copyImg = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")
        let copyBtn = makeIconButton(image: copyImg, toolTip: "Copy Quote", action: #selector(copyClicked))
        stack.addArrangedSubview(copyBtn)
        
        // Delete
        let delImg = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")
        let delBtn = makeIconButton(image: delImg, toolTip: "Delete Annotation", action: #selector(deleteClicked))
        delBtn.contentTintColor = NSColor.systemRed
        delBtn.isHidden = true
        self.deleteButton = delBtn
        stack.addArrangedSubview(delBtn)
    }
    
    private func makeToolButton(title: String, font: NSFont, toolTip: String, action: Selector) -> NSButton {
        let btn = NSButton(title: title, target: self, action: action)
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.font = font
        btn.toolTip = toolTip
        btn.contentTintColor = .white
        return btn
    }
    
    private func makeIconButton(image: NSImage?, toolTip: String, action: Selector) -> NSButton {
        let btn = NSButton(image: image ?? NSImage(), target: self, action: action)
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.toolTip = toolTip
        btn.contentTintColor = .white
        btn.imageScaling = .scaleProportionallyDown
        btn.widthAnchor.constraint(equalToConstant: 20).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 20).isActive = true
        return btn
    }
    
    @objc private func colorClicked(_ sender: NSButton) {
        guard let stack = subviews.first as? NSStackView else { return }
        let colorButtons = stack.arrangedSubviews.filter { $0 is NSButton && ($0 as! NSButton).title.isEmpty && $0 != deleteButton }
        if let idx = colorButtons.firstIndex(of: sender), idx < palette.count {
            let item = palette[idx]
            onColor?(item.hex, item.color)
        } else {
            onColor?(palette[0].hex, palette[0].color)
        }
    }
    
    @objc private func underlineClicked() { onUnderline?() }
    @objc private func strikeClicked() { onStrike?() }
    @objc private func noteClicked() { onNote?() }
    @objc private func copyClicked() { onCopy?() }
    @objc private func deleteClicked() { onDelete?() }
}

class CustomPDFView: PDFView {
    var onAddAnnotation: ((String, String, String, Int) -> Void)? = nil
    var onPromptNote: ((String, String, String, Int) -> Void)? = nil
    var onDeleteAnnotation: ((String, Int) -> Void)? = nil
    var onMouseActivity: (() -> Void)? = nil
    
    private var trackingArea: NSTrackingArea?
    private var annotationBar: PDFAnnotationBarView!
    private var activeAnnotation: PDFAnnotation? = nil
    private var activePage: PDFPage? = nil
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupAnnotationBar()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAnnotationBar()
    }
    
    private func setupAnnotationBar() {
        annotationBar = PDFAnnotationBarView()
        addSubview(annotationBar)
        
        annotationBar.onColor = { [weak self] hex, col in
            self?.applyColorToSelectionOrAnnotation(hex: hex, color: col)
        }
        annotationBar.onUnderline = { [weak self] in
            self?.underlineCurrentSelection()
        }
        annotationBar.onStrike = { [weak self] in
            self?.strikeCurrentSelection()
        }
        annotationBar.onNote = { [weak self] in
            self?.promptNoteForSelectionOrAnnotation()
        }
        annotationBar.onCopy = { [weak self] in
            self?.copySelectedText()
        }
        annotationBar.onDelete = { [weak self] in
            self?.deleteActiveAnnotation()
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let opts: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: bounds, options: opts, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onMouseActivity?()
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        onMouseActivity?()
        
        if let sel = self.currentSelection, let text = sel.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showBarForSelection(sel)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let pointInView = convert(event.locationInWindow, from: nil)
        
        // If clicking inside the annotation bar, let the bar handle it
        if !annotationBar.isHidden && NSPointInRect(pointInView, annotationBar.frame) {
            super.mouseDown(with: event)
            return
        }
        
        super.mouseDown(with: event)
        
        // Check if user clicked an existing annotation
        if let page = self.page(for: pointInView, nearest: false) {
            let pagePoint = convert(pointInView, to: page)
            if let annot = page.annotation(at: pagePoint),
               (annot.type == "Highlight" || annot.type == "Underline" || annot.type == "StrikeOut" || annot.type == "Text") {
                showBarForAnnotation(annot, on: page)
                return
            }
        }
        
        // Hide bar if clicking blank area and no selection
        if currentSelection == nil || currentSelection?.string?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            hideAnnotationBar()
        }
    }
    
    func showBarForSelection(_ sel: PDFSelection) {
        guard let page = sel.pages.first else { return }
        activeAnnotation = nil
        activePage = page
        annotationBar.setHasActiveAnnotation(false)
        
        let boundsOnPage = sel.bounds(for: page)
        let viewRect = convert(boundsOnPage, from: page)
        positionBar(over: viewRect)
    }
    
    func showBarForAnnotation(_ annot: PDFAnnotation, on page: PDFPage) {
        activeAnnotation = annot
        activePage = page
        annotationBar.setHasActiveAnnotation(true)
        
        let viewRect = convert(annot.bounds, from: page)
        positionBar(over: viewRect)
    }
    
    private func positionBar(over viewRect: NSRect) {
        let barW = annotationBar.frame.width
        let barH = annotationBar.frame.height
        let x = max(16, min(bounds.width - barW - 16, viewRect.midX - barW / 2))
        var y = viewRect.maxY + 10
        if y + barH > bounds.height - 12 {
            y = max(12, viewRect.minY - barH - 10)
        }
        annotationBar.frame = NSRect(x: x, y: y, width: barW, height: barH)
        annotationBar.isHidden = false
        annotationBar.alphaValue = 1.0
    }
    
    func hideAnnotationBar() {
        annotationBar.isHidden = true
        activeAnnotation = nil
    }
    
    private func applyColorToSelectionOrAnnotation(hex: String, color: NSColor) {
        if let annot = activeAnnotation {
            annot.color = color
            saveDocumentIfPossible()
            if let page = activePage, let doc = document {
                let pIdx = doc.index(for: page)
                let text = annot.contents ?? ""
                onAddAnnotation?(text, annot.contents ?? "", hex, pIdx)
            }
            hideAnnotationBar()
            return
        }
        
        guard let sel = currentSelection else { return }
        for page in sel.pages {
            // Line-by-line selection for neat highlights
            let lines = sel.selectionsByLine()
            let targets = lines.isEmpty ? [sel] : lines
            for lineSel in targets {
                let lineBounds = lineSel.bounds(for: page)
                if lineBounds.width > 0 && lineBounds.height > 0 {
                    let annot = PDFAnnotation(bounds: lineBounds, forType: .highlight, withProperties: nil)
                    annot.color = color
                    page.addAnnotation(annot)
                }
            }
        }
        saveDocumentIfPossible()
        if let page = sel.pages.first, let doc = document, let text = sel.string {
            let pageIdx = doc.index(for: page)
            onAddAnnotation?(text.trimmingCharacters(in: .whitespacesAndNewlines), "", hex, pageIdx)
        }
        clearSelection()
        hideAnnotationBar()
    }
    
    @objc func highlightYellow() { applyColorToSelectionOrAnnotation(hex: "#FFE270", color: NSColor(srgbRed: 1.0, green: 0.886, blue: 0.439, alpha: 0.65)) }
    @objc func highlightGreen() { applyColorToSelectionOrAnnotation(hex: "#A8F596", color: NSColor(srgbRed: 0.659, green: 0.961, blue: 0.588, alpha: 0.65)) }
    @objc func highlightBlue() { applyColorToSelectionOrAnnotation(hex: "#92D6FF", color: NSColor(srgbRed: 0.573, green: 0.839, blue: 1.0, alpha: 0.65)) }
    @objc func highlightPink() { applyColorToSelectionOrAnnotation(hex: "#FFB3D9", color: NSColor(srgbRed: 1.0, green: 0.702, blue: 0.851, alpha: 0.65)) }
    @objc func highlightPurple() { applyColorToSelectionOrAnnotation(hex: "#D2B4FF", color: NSColor(srgbRed: 0.824, green: 0.706, blue: 1.0, alpha: 0.65)) }
    
    @objc func underlineCurrentSelection() {
        guard let sel = currentSelection else { return }
        for page in sel.pages {
            let lines = sel.selectionsByLine()
            let targets = lines.isEmpty ? [sel] : lines
            for lineSel in targets {
                let bounds = lineSel.bounds(for: page)
                if bounds.width > 0 && bounds.height > 0 {
                    let annot = PDFAnnotation(bounds: bounds, forType: .underline, withProperties: nil)
                    annot.color = NSColor.systemOrange
                    page.addAnnotation(annot)
                }
            }
        }
        saveDocumentIfPossible()
        if let page = sel.pages.first, let doc = document, let text = sel.string {
            let pageIdx = doc.index(for: page)
            onAddAnnotation?(text.trimmingCharacters(in: .whitespacesAndNewlines), "", "#FF9500", pageIdx)
        }
        clearSelection()
        hideAnnotationBar()
    }
    
    @objc func strikeCurrentSelection() {
        guard let sel = currentSelection else { return }
        for page in sel.pages {
            let lines = sel.selectionsByLine()
            let targets = lines.isEmpty ? [sel] : lines
            for lineSel in targets {
                let bounds = lineSel.bounds(for: page)
                if bounds.width > 0 && bounds.height > 0 {
                    let annot = PDFAnnotation(bounds: bounds, forType: .strikeOut, withProperties: nil)
                    annot.color = NSColor.systemRed
                    page.addAnnotation(annot)
                }
            }
        }
        saveDocumentIfPossible()
        clearSelection()
        hideAnnotationBar()
    }
    
    private func promptNoteForSelectionOrAnnotation() {
        let text: String
        let existingNote: String
        let pageIdx: Int
        
        if let annot = activeAnnotation, let page = activePage, let doc = document {
            text = annot.contents ?? ""
            existingNote = annot.contents ?? ""
            pageIdx = doc.index(for: page)
        } else if let sel = currentSelection, let page = sel.pages.first, let doc = document {
            text = sel.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            existingNote = ""
            pageIdx = doc.index(for: page)
            // Apply default yellow highlight so the quote stays visually marked
            applyColorToSelectionOrAnnotation(hex: "#FFE270", color: NSColor(srgbRed: 1.0, green: 0.886, blue: 0.439, alpha: 0.65))
        } else {
            return
        }
        
        hideAnnotationBar()
        onPromptNote?(text, existingNote, "#FFE270", pageIdx)
    }
    
    @objc func copySelectedText() {
        let str: String
        if let s = currentSelection?.string, !s.isEmpty {
            str = s
        } else if let a = activeAnnotation?.contents, !a.isEmpty {
            str = a
        } else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(str, forType: .string)
        clearSelection()
        hideAnnotationBar()
    }
    
    func deleteActiveAnnotation() {
        guard let annot = activeAnnotation, let page = activePage else { return }
        let text = annot.contents ?? ""
        page.removeAnnotation(annot)
        saveDocumentIfPossible()
        if let doc = document {
            let pageIdx = doc.index(for: page)
            onDeleteAnnotation?(text, pageIdx)
        }
        hideAnnotationBar()
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        if let sel = self.currentSelection, let selString = sel.string, !selString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            menu.addItem(NSMenuItem.separator())
            
            let yHl = NSMenuItem(title: "Highlight (Yellow)", action: #selector(highlightYellow), keyEquivalent: "")
            yHl.target = self
            menu.addItem(yHl)
            
            let gHl = NSMenuItem(title: "Highlight (Green)", action: #selector(highlightGreen), keyEquivalent: "")
            gHl.target = self
            menu.addItem(gHl)
            
            let bHl = NSMenuItem(title: "Highlight (Blue)", action: #selector(highlightBlue), keyEquivalent: "")
            bHl.target = self
            menu.addItem(bHl)
            
            let underItem = NSMenuItem(title: "Underline Selection", action: #selector(underlineCurrentSelection), keyEquivalent: "")
            underItem.target = self
            menu.addItem(underItem)
            
            let strikeItem = NSMenuItem(title: "Strikethrough Selection", action: #selector(strikeCurrentSelection), keyEquivalent: "")
            strikeItem.target = self
            menu.addItem(strikeItem)
            
            let noteItem = NSMenuItem(title: "Add Note...", action: #selector(menuAddNote), keyEquivalent: "")
            noteItem.target = self
            menu.addItem(noteItem)
            
            let copyItem = NSMenuItem(title: "Copy Selection", action: #selector(copySelectedText), keyEquivalent: "")
            copyItem.target = self
            menu.addItem(copyItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        let openPreviewItem = NSMenuItem(title: "Open in Preview (View Images/Diagrams)", action: #selector(openInPreview), keyEquivalent: "")
        openPreviewItem.target = self
        menu.addItem(openPreviewItem)
        
        return menu
    }
    
    @objc private func menuAddNote() {
        promptNoteForSelectionOrAnnotation()
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

struct NativePDFKitView: NSViewRepresentable {
    let url: URL
    var themeBackgroundColor: NSColor = .windowBackgroundColor
    var pdfDisplayMode: String = "book" // "single", "book", "continuous"
    var initialPage: Int = 0
    @Binding var targetPage: Int?
    var triggerNextPage: Int = 0
    var triggerPrevPage: Int = 0
    var zoomInTrigger: Int = 0
    var zoomOutTrigger: Int = 0
    var zoomResetTrigger: Int = 0
    @Binding var activePDFView: PDFView?
    var onPageChange: ((Int, Int) -> Void)? = nil
    var onAddAnnotation: ((String, String, String, Int) -> Void)? = nil
    var onPromptNote: ((String, String, String, Int) -> Void)? = nil
    var onDeleteAnnotation: ((String, Int) -> Void)? = nil
    var onMouseActivity: (() -> Void)? = nil
    
    private var resolvedURL: URL {
        let p = (url.path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: p)
    }
    
    private func configureDisplayMode(on pdfView: CustomPDFView, mode: String) {
        let targetMode: PDFDisplayMode
        let asBook: Bool
        switch mode {
        case "book":
            targetMode = .twoUp
            asBook = true
        case "continuous":
            targetMode = .singlePageContinuous
            asBook = false
        default: // "single"
            targetMode = .singlePage
            asBook = false
        }
        var changed = false
        if pdfView.displayMode != targetMode {
            pdfView.displayMode = targetMode
            changed = true
        }
        if pdfView.displaysAsBook != asBook {
            pdfView.displaysAsBook = asBook
            changed = true
        }
        if changed {
            pdfView.layoutDocumentView()
        }
    }
    
    func makeNSView(context: Context) -> CustomPDFView {
        let pdfView = CustomPDFView()
        pdfView.onAddAnnotation = onAddAnnotation
        pdfView.onPromptNote = onPromptNote
        pdfView.onDeleteAnnotation = onDeleteAnnotation
        pdfView.onMouseActivity = onMouseActivity
        if let doc = PDFDocument(url: resolvedURL) {
            pdfView.document = doc
        }
        pdfView.autoScales = true
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = themeBackgroundColor
        configureDisplayMode(on: pdfView, mode: pdfDisplayMode)
        pdfView.layoutDocumentView()
        
        // Restore initial reading page position
        if initialPage > 0, let doc = pdfView.document, initialPage < doc.pageCount {
            if let page = doc.page(at: initialPage) {
                pdfView.go(to: page)
            }
        }
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        DispatchQueue.main.async {
            self.activePDFView = pdfView
        }
        
        return pdfView
    }
    
    func updateNSView(_ pdfView: CustomPDFView, context: Context) {
        pdfView.onAddAnnotation = onAddAnnotation
        pdfView.onPromptNote = onPromptNote
        pdfView.onDeleteAnnotation = onDeleteAnnotation
        pdfView.onMouseActivity = onMouseActivity
        
        if pdfView.backgroundColor != themeBackgroundColor {
            pdfView.backgroundColor = themeBackgroundColor
        }
        
        configureDisplayMode(on: pdfView, mode: pdfDisplayMode)
        
        if pdfView.document == nil || pdfView.document?.documentURL?.path != resolvedURL.path {
            if let doc = PDFDocument(url: resolvedURL) {
                pdfView.document = doc
                pdfView.autoScales = true
                pdfView.layoutDocumentView()
            }
        }
        
        // Handle triggerNextPage
        if triggerNextPage > context.coordinator.lastTriggerNext {
            context.coordinator.lastTriggerNext = triggerNextPage
            if pdfView.canGoToNextPage {
                pdfView.goToNextPage(nil)
            }
        }
        
        // Handle triggerPrevPage
        if triggerPrevPage > context.coordinator.lastTriggerPrev {
            context.coordinator.lastTriggerPrev = triggerPrevPage
            if pdfView.canGoToPreviousPage {
                pdfView.goToPreviousPage(nil)
            }
        }
        
        // Handle Zoom In
        if zoomInTrigger > context.coordinator.lastZoomIn {
            context.coordinator.lastZoomIn = zoomInTrigger
            pdfView.zoomIn(nil)
        }
        
        // Handle Zoom Out
        if zoomOutTrigger > context.coordinator.lastZoomOut {
            context.coordinator.lastZoomOut = zoomOutTrigger
            pdfView.zoomOut(nil)
        }
        
        // Handle Zoom Reset
        if zoomResetTrigger > context.coordinator.lastZoomReset {
            context.coordinator.lastZoomReset = zoomResetTrigger
            pdfView.autoScales = true
            pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        }
        
        // Handle target page jump
        if let target = targetPage, let doc = pdfView.document, target >= 0 && target < doc.pageCount {
            if let page = doc.page(at: target), pdfView.currentPage != page {
                pdfView.go(to: page)
            }
            DispatchQueue.main.async {
                self.targetPage = nil
            }
        }
        
        if activePDFView !== pdfView {
            DispatchQueue.main.async {
                self.activePDFView = pdfView
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: NativePDFKitView
        var lastTriggerNext: Int = 0
        var lastTriggerPrev: Int = 0
        var lastZoomIn: Int = 0
        var lastZoomOut: Int = 0
        var lastZoomReset: Int = 0
        
        init(_ parent: NativePDFKitView) {
            self.parent = parent
            self.lastTriggerNext = parent.triggerNextPage
            self.lastTriggerPrev = parent.triggerPrevPage
            self.lastZoomIn = parent.zoomInTrigger
            self.lastZoomOut = parent.zoomOutTrigger
            self.lastZoomReset = parent.zoomResetTrigger
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

//
//  PDFThumbnailSwiftUIView
//  Native live page thumbnail strip matching Preview's iconic thumbnail sidebar.
//
struct PDFThumbnailSwiftUIView: NSViewRepresentable {
    let pdfView: PDFView?
    
    func makeNSView(context: Context) -> PDFThumbnailView {
        let thumbView = PDFThumbnailView()
        thumbView.pdfView = pdfView
        thumbView.thumbnailSize = NSSize(width: 130, height: 170)
        thumbView.backgroundColor = .clear
        return thumbView
    }
    
    func updateNSView(_ thumbView: PDFThumbnailView, context: Context) {
        if thumbView.pdfView !== pdfView {
            thumbView.pdfView = pdfView
        }
    }
}
