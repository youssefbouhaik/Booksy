//
//  BookWebView.swift
//  Folio / Books
//
//  WebKit Book View with Floating Annotation Suite, Dynamic Pagination, and Real-Time Audio-Synced Highlighting
//

import SwiftUI
import AppKit
import WebKit

// MARK: - BookWKWebView (Custom WebKit subclass)
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

// MARK: - BookWebView
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
    var onPromptNote: ((String, String, String) -> Void)? = nil
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
                    let note = dict["note"] as? String ?? ""
                    let colorHex = dict["colorHex"] as? String ?? "#FFE270"
                    parent.onPromptNote?(text, note, colorHex)
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
        
        @objc func handleFindInPage(_ notification: Notification) {
            guard let wv = webView,
                  let dict = notification.userInfo as? [String: Any],
                  let query = dict["query"] as? String, !query.isEmpty else { return }
            let backwards = dict["backwards"] as? Bool ?? false
            let escaped = query
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
            wv.evaluateJavaScript("window.find('\(escaped)', false, \(backwards), true, false, false, false)")
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
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        webView.setValue(false, forKey: "drawsBackground")
        webView.postsFrameChangedNotifications = true
        context.coordinator.webView = webView
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.viewFrameChanged(_:)),
            name: NSView.frameDidChangeNotification,
            object: webView
        )
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleFindInPage(_:)),
            name: NSNotification.Name("BooksyFindInPage"),
            object: nil
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
        
        let contentKey = "\(chapterIndex)_\(bookPath)_\(readerTheme)_\(fontSize)_\(fontFamily)_\(isBoldText)_\(isTwoPageSpread)_\(isEditMode)_\(htmlContent.count)_\(lineSpacing)_\(characterSpacing)_\(wordSpacing)_\(marginScale)_\(columnsOption)_\(justifyText)"
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
                transition: transform 0.42s cubic-bezier(0.16, 1, 0.3, 1);
            }
            /* No separation element between pages */
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
                width: max(\(marginX)px, 10vw);
                cursor: pointer;
                z-index: 5;
            }
            .nav-strip-right {
                position: fixed;
                right: 0;
                top: 0;
                bottom: 0;
                width: max(\(marginX)px, 10vw);
                cursor: pointer;
                z-index: 5;
            }
            
            /* Floating Apple Books Annotation Suite */
            #booksy-annotation-bar {
                position: fixed;
                z-index: 99999;
                display: none;
                align-items: center;
                gap: 8px;
                padding: 7px 13px;
                background: rgba(26, 26, 28, 0.98);
                backdrop-filter: blur(30px);
                -webkit-backdrop-filter: blur(30px);
                border-radius: 22px;
                border: 1px solid rgba(255, 255, 255, 0.20);
                box-shadow: 0 12px 32px rgba(0, 0, 0, 0.50), 0 2px 6px rgba(0, 0, 0, 0.30);
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
                width: 20px;
                height: 20px;
                border-radius: 50%;
                cursor: pointer;
                transition: transform 0.12s ease;
                border: 1.5px solid rgba(255, 255, 255, 0.35);
                flex-shrink: 0;
            }
            .booksy-color-chip:hover {
                transform: scale(1.22);
            }
            .chip-yellow { background-color: #FFD60A; }
            .chip-green { background-color: #32D74B; }
            .chip-blue { background-color: #0A84FF; }
            .chip-pink { background-color: #FF375F; }
            .chip-purple { background-color: #BF5AF2; }
            
            .booksy-divider {
                width: 1px;
                height: 18px;
                background: rgba(255, 255, 255, 0.22);
                margin: 0 3px;
            }
            .booksy-tool-btn {
                background: transparent;
                border: none;
                color: #FFFFFF;
                display: inline-flex;
                align-items: center;
                justify-content: center;
                cursor: pointer;
                padding: 4px 7px;
                border-radius: 6px;
                transition: all 0.12s ease;
                font-size: 12px;
                font-weight: 600;
            }
            .booksy-tool-btn:hover {
                background: rgba(255, 255, 255, 0.22);
                transform: scale(1.08);
            }
            
            /* Highlight Marks in Body */
            mark.booksy-highlight {
                background-color: #FFD60A;
                color: inherit;
                border-radius: 3px;
                padding: 1px 2px;
                cursor: pointer;
            }
            body[style*="background-color: #000000"] mark.booksy-highlight,
            body[style*="background-color: #2C2C2E"] mark.booksy-highlight {
                color: #111111 !important;
                font-weight: 500;
            }
            span.booksy-underline {
                text-decoration: underline;
                text-decoration-color: #FF9500;
                text-decoration-thickness: 2.5px;
                cursor: pointer;
            }
            span.booksy-strike {
                text-decoration: line-through;
                text-decoration-color: #FF453A;
                text-decoration-thickness: 2px;
                cursor: pointer;
            }
            mark.booksy-highlight[data-note]::after,
            span.booksy-underline[data-note]::after,
            span.booksy-strike[data-note]::after {
                content: " 📝";
                font-size: 10px;
                vertical-align: super;
                line-height: 0;
                opacity: 0.9;
                cursor: pointer;
            }
        </style>
        </head>
        <body id="book-body" class="\(isEditMode ? "edit-active" : "")">
            <div class="nav-strip-left" onclick="prevSpread()"></div>
            <div class="nav-strip-right" onclick="nextSpread()"></div>
            
            <div id="booksy-annotation-bar" onmousedown="event.preventDefault();">
                <div class="booksy-color-chip chip-yellow" title="Yellow" onmousedown="event.preventDefault();" onclick="applyHighlight('#FFD60A')"></div>
                <div class="booksy-color-chip chip-green" title="Green" onmousedown="event.preventDefault();" onclick="applyHighlight('#32D74B')"></div>
                <div class="booksy-color-chip chip-blue" title="Blue" onmousedown="event.preventDefault();" onclick="applyHighlight('#0A84FF')"></div>
                <div class="booksy-color-chip chip-pink" title="Pink" onmousedown="event.preventDefault();" onclick="applyHighlight('#FF375F')"></div>
                <div class="booksy-color-chip chip-purple" title="Purple" onmousedown="event.preventDefault();" onclick="applyHighlight('#BF5AF2')"></div>
                <div class="booksy-divider"></div>
                <button class="booksy-tool-btn" title="Underline" onmousedown="event.preventDefault();" onclick="applyUnderline()">
                    <span style="text-decoration: underline; font-weight: bold; font-family: serif; font-size: 13px;">U</span>
                </button>
                <button class="booksy-tool-btn" title="Strikethrough" onmousedown="event.preventDefault();" onclick="applyStrikethrough()">
                    <span style="text-decoration: line-through; font-weight: bold; font-family: serif; font-size: 13px;">S</span>
                </button>
                <button class="booksy-tool-btn" title="Add Note" onmousedown="event.preventDefault();" onclick="promptAddNote()">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"></path><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"></path></svg>
                    <span style="margin-left: 3px;">Note</span>
                </button>
                <button class="booksy-tool-btn" title="Copy Text" onmousedown="event.preventDefault();" onclick="copySelectionText()">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>
                </button>
                <button id="booksy-delete-btn" class="booksy-tool-btn" title="Delete Highlight" style="display: none;" onmousedown="event.preventDefault();" onclick="deleteActiveHighlight()">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#FF453A" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path></svg>
                </button>
            </div>
            
            <div id="book-columns" \(editAttr)>
                \(htmlContent)
            </div>
            
            <script>
                const targetInitialSpread = \(seekToSpread);
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
                        var spreadWidth = getSpreadWidth();
                        var allEls = columnsEl.querySelectorAll('p, h1, h2, h3, h4, h5, h6, blockquote, li');
                        var snippet = '';
                        for (var i = 0; i < allEls.length; i++) {
                            var rect = allEls[i].getBoundingClientRect();
                            if (rect.width > 0 && rect.bottom > 20 && rect.top < window.innerHeight - 20 && rect.left >= -20 && rect.left < spreadWidth - 20) {
                                var text = allEls[i].textContent || '';
                                var trimmed = text.trim();
                                if (trimmed.length > 5) {
                                    snippet = trimmed;
                                    break;
                                }
                            }
                        }
                        if (snippet.length > 0 && window.webkit && window.webkit.messageHandlers.visibleSnippet) {
                            window.webkit.messageHandlers.visibleSnippet.postMessage(snippet.substring(0, 300));
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
                        try {
                            updateDisplay();
                        } finally {
                            setTimeout(function() { isTurningPage = false; }, 380);
                        }
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
                        try {
                            updateDisplay();
                        } finally {
                            setTimeout(function() { isTurningPage = false; }, 380);
                        }
                    } else {
                        if (window.webkit && window.webkit.messageHandlers.pageNav) {
                            window.webkit.messageHandlers.pageNav.postMessage("prevChapter");
                        }
                    }
                }
                
                function goToSpread(target) {
                    hideAnnotationBar();
                    const total = getTotalSpreads();
                    if (target === -1 || target >= 999999) {
                        currentSpread = Math.max(0, total - 1);
                    } else {
                        currentSpread = Math.max(0, Math.min(total - 1, target - 1));
                    }
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
                
                function applyStrikethrough() {
                    if (activeTargetHighlight) {
                        activeTargetHighlight.style.backgroundColor = 'transparent';
                        activeTargetHighlight.style.textDecoration = 'line-through';
                        activeTargetHighlight.style.textDecorationColor = '#FF453A';
                        activeTargetHighlight.style.textDecorationThickness = '2px';
                        activeTargetHighlight.setAttribute('data-color', '#FF453A');
                        const text = activeTargetHighlight.getAttribute('data-text') || activeTargetHighlight.textContent;
                        hideAnnotationBar();
                        if (window.webkit && window.webkit.messageHandlers.createAnnotation) {
                            window.webkit.messageHandlers.createAnnotation.postMessage({
                                text: text,
                                colorHex: '#FF453A',
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
                        span.className = 'booksy-strike';
                        span.setAttribute('data-color', '#FF453A');
                        span.setAttribute('data-text', selectedText);
                        span.style.textDecoration = 'line-through';
                        span.style.textDecorationColor = '#FF453A';
                        span.style.textDecorationThickness = '2px';
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
                                colorHex: '#FF453A',
                                note: ""
                            });
                        }
                    } catch(err) {
                        console.error("Strike error:", err);
                    }
                }
                
                function copySelectionText() {
                    let textToCopy = "";
                    if (activeTargetHighlight) {
                        textToCopy = activeTargetHighlight.getAttribute('data-text') || activeTargetHighlight.textContent;
                    } else {
                        const sel = window.getSelection();
                        if (sel) textToCopy = sel.toString().trim();
                    }
                    if (textToCopy) {
                        navigator.clipboard.writeText(textToCopy);
                    }
                    hideAnnotationBar();
                }
                
                function promptAddNote() {
                    let textToNote = "";
                    let colorHex = "#FFE270";
                    let existingNote = "";
                    if (activeTargetHighlight) {
                        textToNote = activeTargetHighlight.getAttribute('data-text') || activeTargetHighlight.textContent;
                        colorHex = activeTargetHighlight.getAttribute('data-color') || "#FFE270";
                        existingNote = activeTargetHighlight.getAttribute('data-note') || "";
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
                            colorHex: colorHex,
                            note: existingNote
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
                                if (note && note.trim().length > 0) {
                                    mark.setAttribute('data-note', note);
                                    mark.setAttribute('title', note);
                                }
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
                
                // Trackpad Two-Finger Swipe & Mouse Wheel Page Scrolling
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
                
                let initialSpreadApplied = false;
                function applyInitialSpread() {
                    if (initialSpreadApplied) return;
                    if (typeof targetInitialSpread === 'number' && (targetInitialSpread > 1 || targetInitialSpread === -1 || targetInitialSpread >= 999999)) {
                        const total = getTotalSpreads();
                        if (total > 1 || document.readyState === 'complete') {
                            goToSpread(targetInitialSpread);
                            initialSpreadApplied = true;
                        }
                    } else {
                        initialSpreadApplied = true;
                    }
                }

                // Continuous Dynamic Page Calculation on Window Resizing
                function handleResize() {
                    applyInitialSpread();
                    const totalNow = getTotalSpreads();
                    currentSpread = Math.max(0, Math.min(totalNow - 1, currentSpread));
                    columnsEl.style.transform = 'translateX(' + (-currentSpread * getSpreadWidth()) + 'px)';
                    reportMetrics();
                }
                window.addEventListener('resize', handleResize);
                
                if (window.ResizeObserver) {
                    const ro = new ResizeObserver(function() {
                        handleResize();
                    });
                    ro.observe(document.body);
                }
                
                setTimeout(function() {
                    applyInitialSpread();
                    reportMetrics();
                    applySavedHighlights(savedHighlights);
                }, 50);

                setTimeout(function() {
                    applyInitialSpread();
                    reportMetrics();
                }, 180);
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(styledHTML, baseURL: URL(fileURLWithPath: bookPath))
    }
}
