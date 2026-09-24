//
//  ReaderWindowManager.swift
//  Folio / Books
//

import SwiftUI
import AppKit

class ReaderWindowManager: NSObject, NSWindowDelegate {
    static let shared = ReaderWindowManager()
    
    private var windowControllers: [String: NSWindowController] = [:]
    
    func openReader(for book: Book) {
        let key = book.path ?? book.title
        
        // If window already open, bring it to front
        if let existingController = windowControllers[key], let window = existingController.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create a standalone native NSWindow matching Apple Books
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1060, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = book.title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 800, height: 600)
        window.center()
        
        let readerView = EmbeddedReaderView(book: book, isStandaloneWindow: true) {
            window.close()
        }
        
        let hostingView = NSHostingView(rootView: readerView)
        window.contentView = hostingView
        window.delegate = self
        
        let controller = NSWindowController(window: window)
        windowControllers[key] = controller
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        EmbeddedReaderView.killGlobalAudio()
        for (key, controller) in windowControllers {
            if controller.window == window {
                windowControllers.removeValue(forKey: key)
                break
            }
        }
    }
}
