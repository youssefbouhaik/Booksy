//
//  SearchView.swift
//  Books
//

import SwiftUI

enum SearchCategoryFilter: String, CaseIterable {
    case all = "All"
    case books = "Books"
    case pdfs = "PDFs"
}

enum SearchViewMode: String {
    case grid = "square.grid.2x2"
    case list = "list.bullet"
}

struct SearchView: View {
    @ObservedObject var booksVM = BooksViewModel.shared
    @Environment(\.colorScheme) var colorScheme
    
    @State private var searchText: String = ""
    @State private var selectedFilter: SearchCategoryFilter = .all
    @State private var viewMode: SearchViewMode = .grid
    @FocusState private var isSearchFieldFocused: Bool
    
    private var allCount: Int { booksVM.visibleBooks.count }
    private var booksCount: Int { booksVM.visibleBooks.filter { $0.isEPUB }.count }
    private var pdfsCount: Int { booksVM.visibleBooks.filter { $0.isPDF }.count }
    
    var filteredBooks: [Book] {
        let baseList: [Book]
        switch selectedFilter {
        case .all:
            baseList = booksVM.visibleBooks
        case .books:
            baseList = booksVM.visibleBooks.filter { $0.isEPUB }
        case .pdfs:
            baseList = booksVM.visibleBooks.filter { $0.isPDF }
        }
        
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return baseList
        }
        
        return baseList.filter { book in
            let titleMatch = book.title.localizedCaseInsensitiveContains(query)
            let authorMatch = book.author.localizedCaseInsensitiveContains(query)
            let pathMatch = book.path.map { ($0 as NSString).lastPathComponent.localizedCaseInsensitiveContains(query) } ?? false
            return titleMatch || authorMatch || pathMatch
        }
    }
    
    private let gridColumns = [
        GridItem(.adaptive(minimum: 140, maximum: 170), spacing: 28)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Search & Filter Bar
            searchHeaderView
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 16)
            
            Divider()
                .padding(.horizontal, 28)
            
            // Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Empty Search State / Library Explorer
                        emptySearchLandingView
                    } else if filteredBooks.isEmpty {
                        // No Results State
                        noResultsView
                    } else {
                        // Results View
                        resultsHeaderView
                        
                        if viewMode == .grid {
                            resultsGridView
                        } else {
                            resultsListView
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
            }
        }
    }
    
    // MARK: - Header & Search Bar
    
    private var searchHeaderView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Search")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                    
                    Text("Search your library books, documents, and authors")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // View Mode Switcher
                HStack(spacing: 2) {
                    Button(action: { viewMode = .grid }) {
                        Image(systemName: SearchViewMode.grid.rawValue)
                            .font(.system(size: 13, weight: viewMode == .grid ? .semibold : .regular))
                            .foregroundColor(viewMode == .grid ? .primary : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(viewMode == .grid ? Color.primary.opacity(0.12) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { viewMode = .list }) {
                        Image(systemName: SearchViewMode.list.rawValue)
                            .font(.system(size: 13, weight: viewMode == .list ? .semibold : .regular))
                            .foregroundColor(viewMode == .list ? .primary : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(viewMode == .list ? Color.primary.opacity(0.12) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(3)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
            }
            
            // Search Input Field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("Search by title, author, or keyword...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isSearchFieldFocused)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSearchFieldFocused ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: 1)
            )
            
            // Category Filter Pills
            HStack(spacing: 8) {
                filterPill(filter: .all, count: allCount)
                filterPill(filter: .books, count: booksCount)
                filterPill(filter: .pdfs, count: pdfsCount)
                
                Spacer()
            }
        }
    }
    
    private func filterPill(filter: SearchCategoryFilter, count: Int) -> some View {
        let isSelected = selectedFilter == filter
        return Button(action: {
            selectedFilter = filter
        }) {
            HStack(spacing: 6) {
                Text(filter.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(isSelected ? Color.white.opacity(0.25) : Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.10))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Results Views
    
    private var resultsHeaderView: some View {
        HStack {
            Text("\(filteredBooks.count) \(filteredBooks.count == 1 ? "Result" : "Results")")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.top, 4)
    }
    
    private var resultsGridView: some View {
        LazyVGrid(columns: gridColumns, spacing: 32) {
            ForEach(filteredBooks) { book in
                Button(action: {
                    ReaderWindowManager.shared.openReader(for: book)
                }) {
                    BookCoverView(book: book, width: 140)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()
                .contextMenu {
                    contextMenuItems(for: book)
                }
            }
        }
    }
    
    private var resultsListView: some View {
        VStack(spacing: 8) {
            ForEach(filteredBooks) { book in
                Button(action: {
                    ReaderWindowManager.shared.openReader(for: book)
                }) {
                    HStack(spacing: 16) {
                        BookCoverView(book: book, width: 44, showTitle: false)
                            .frame(width: 44, height: 66)
                            .cornerRadius(4)
                            .shadow(color: Color.black.opacity(0.12), radius: 3, x: 1, y: 2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Text(book.author)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            if let p = book.path {
                                Text((p as NSString).lastPathComponent)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary.opacity(0.7))
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        // Badge
                        Text(book.isPDF ? "PDF" : "EPUB")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(6)
                        
                        // Open Button
                        Text("Open")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    )
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()
                .contextMenu {
                    contextMenuItems(for: book)
                }
            }
        }
    }
    
    // MARK: - Empty & No Results
    
    private var emptySearchLandingView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Quick Hero Card
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search Your Collection")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                    
                    Text("\(allCount) books and documents indexed and ready to search.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            
            // Recently Added / Library Quick Shelf
            if !booksVM.visibleBooks.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Browse Library (\(filteredBooks.count))")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                    
                    LazyVGrid(columns: gridColumns, spacing: 32) {
                        ForEach(filteredBooks) { book in
                            Button(action: {
                                ReaderWindowManager.shared.openReader(for: book)
                            }) {
                                BookCoverView(book: book, width: 140)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .focusEffectDisabled()
                            .contextMenu {
                                contextMenuItems(for: book)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary.opacity(0.5))
                .padding(.top, 40)
            
            Text("No Results for \"\(searchText)\"")
                .font(.system(size: 18, weight: .bold, design: .serif))
            
            Text("Check the spelling or try searching for another author, title, or document keyword.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            
            Button("Clear Search") {
                searchText = ""
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func contextMenuItems(for book: Book) -> some View {
        Button(action: {
            ReaderWindowManager.shared.openReader(for: book)
        }) {
            Label("Read Now", systemImage: "book")
        }
        
        Button(action: {
            FinishedBooksManager.shared.markAsFinished(book: book)
        }) {
            Label("Mark as Finished", systemImage: "checkmark.circle")
        }
        
        Divider()
        
        if booksVM.hiddenKeys.contains(book.path ?? book.title) {
            Button(action: {
                booksVM.unhideBook(book: book)
            }) {
                Label("Unhide Book", systemImage: "eye")
            }
        } else {
            Button(action: {
                booksVM.hideBook(book: book)
            }) {
                Label("Hide Book", systemImage: "eye.slash")
            }
        }
        
        Button(role: .destructive, action: {
            booksVM.removeBook(book: book)
        }) {
            Label("Remove from Collection", systemImage: "trash")
        }
        
        Divider()
        
        if let path = book.path {
            Button(action: {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                task.arguments = ["-R", path]
                try? task.run()
            }) {
                Label("Show in Finder", systemImage: "folder")
            }
        }
    }
}
