//
//  NativePDFKitView.swift
//  Folio / Books
//
//  PDFKit reader view with custom right-click annotations and multi-color highlights
//

import SwiftUI
import AppKit
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
