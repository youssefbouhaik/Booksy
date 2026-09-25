//
//  BooksApp.swift
//  Booksy
//
//  Created by Matthew Andrea D'Alessio on 13/11/23.
//

import SwiftUI

enum NavigationSection: String, CaseIterable, Identifiable {
    case search = "search"
    case home = "home"
    case all = "all"
    case books = "books"
    case pdfs = "pdfs"
    case wantToRead = "wantToRead"
    case finished = "finished"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .search: return "Search"
        case .home: return "Home"
        case .all: return "All"
        case .books: return "Books"
        case .pdfs: return "PDFs"
        case .wantToRead: return "Want to Read"
        case .finished: return "Finished"
        }
    }
    
    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .home: return "house"
        case .all: return "books.vertical"
        case .books: return "book"
        case .pdfs: return "doc.text"
        case .wantToRead: return "arrow.right.circle"
        case .finished: return "checkmark.circle"
        }
    }
}

#if os(macOS)
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            self.cleanWindows()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.cleanWindows()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.cleanWindows()
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cleanWindows()
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cleanWindows()
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cleanWindows()
        }
    }
    
    func cleanWindows() {
        for window in NSApp.windows {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.title = ""
            window.autorecalculatesKeyViewLoop = false
            
            // Recursively strip focus rings from titlebar, sidebar toggle, and toolbar
            if let frameView = window.contentView?.superview {
                stripFocusRings(from: frameView)
            }
            if let cv = window.contentView {
                stripFocusRings(from: cv)
            }
        }
    }
    
    private func stripFocusRings(from view: NSView) {
        view.focusRingType = .none
        for subview in view.subviews {
            stripFocusRings(from: subview)
        }
    }
    
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for path in filenames {
            openBook(at: path)
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            openBook(at: url.path)
        }
    }
    
    private func openBook(at path: String) {
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()
        guard ext == "epub" || ext == "pdf" || ext == "mobi" else { return }
        
        let title = url.deletingPathExtension().lastPathComponent
        let cover = ext == "pdf" ? "doc.text.fill" : "book.closed"
        let book = Book(
            title: title,
            author: "Local Library",
            cover: cover,
            path: path
        )
        BooksViewModel.registerOpenedBook(path: path)
        DispatchQueue.main.async {
            ReaderWindowManager.shared.openReader(for: book)
        }
    }
}
#endif

@main
struct BooksApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    @State private var selectedSection: NavigationSection? = .home
    @State private var isLibraryExpanded: Bool = true
    
    @ViewBuilder
    private func sidebarRow(section: NavigationSection) -> some View {
        NavigationLink(value: section) {
            Label(section.title, systemImage: section.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(selectedSection == section ? .primary : .secondary)
                .padding(.vertical, 3)
        }
        .listRowBackground(
            Group {
                if selectedSection == section {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.10))
                } else {
                    Color.clear
                }
            }
        )
    }
    
    var body: some Scene {
        WindowGroup("") {
            #if os(macOS)
            NavigationSplitView {
                List(selection: $selectedSection) {
                    SwiftUI.Section {
                        sidebarRow(section: .search)
                        sidebarRow(section: .home)
                    }
                    
                    DisclosureGroup(isExpanded: $isLibraryExpanded) {
                        sidebarRow(section: .all)
                        sidebarRow(section: .wantToRead)
                        sidebarRow(section: .finished)
                        sidebarRow(section: .books)
                        sidebarRow(section: .pdfs)
                    } label: {
                        Text("Library")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .listStyle(.sidebar)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
                .focusable(false)
                .focusEffectDisabled()
                .accentColor(.clear)
                .navigationTitle("")
                .onAppear {
                    DispatchQueue.main.async {
                        self.appDelegate.cleanWindows()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.appDelegate.cleanWindows()
                    }
                }
            } detail: {
                Group {
                    switch selectedSection {
                    case .search:
                        SearchView()
                    case .home:
                        HomeView()
                    case .all:
                        LibraryView(filter: .all)
                    case .books:
                        LibraryView(filter: .books)
                    case .pdfs:
                        LibraryView(filter: .pdfs)
                    case .wantToRead:
                        WantToReadView()
                    case .finished:
                        FinishedBooksView()
                    case .none:
                        HomeView()
                    }
                }
                .navigationTitle("")
                .frame(minWidth: 700, minHeight: 600)
            }
            .navigationTitle("")
            .tint(Color.primary)
            .frame(minWidth: 960, minHeight: 680)
            .onOpenURL { url in
                let path = url.path
                let ext = url.pathExtension.lowercased()
                guard ext == "epub" || ext == "pdf" || ext == "mobi" else { return }
                let title = url.deletingPathExtension().lastPathComponent
                let cover = ext == "pdf" ? "doc.text.fill" : "book.closed"
                let book = Book(
                    title: title,
                    author: "Local Library",
                    cover: cover,
                    path: path
                )
                BooksViewModel.registerOpenedBook(path: path)
                DispatchQueue.main.async {
                    ReaderWindowManager.shared.openReader(for: book)
                }
            }
            #else
            TabView(selection: Binding(
                get: { selectedSection?.rawValue ?? "home" },
                set: { selectedSection = NavigationSection(rawValue: $0) }
            )) {
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .tag("home")
                
                LibraryView(filter: .all)
                    .tabItem {
                        Image(systemName: "books.vertical.fill")
                        Text("Library")
                    }
                    .tag("all")
                
                SearchView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                    .tag("search")
            }
            #endif
        }
    }
}
