//
//  ReadNowView.swift
//  Folio / Books
//

import SwiftUI

typealias ReadNowView = HomeView

struct HomeView: View {
    @ObservedObject var goalsManager = ReadingGoalsManager.shared
    @ObservedObject var readingManager = CurrentlyReadingManager.shared
    @ObservedObject var finishedManager = FinishedBooksManager.shared
    @ObservedObject var wantToReadManager = WantToReadManager.shared
    @State private var selectedBookForDetail: Book?
    @State private var showOnboardingSheet: Bool = false
    
    // Genuine currently reading books that the user has actually opened & actively read
    var continueBooks: [Book] {
        readingManager.readingList
    }
    
    var finishedBooks: [Book] {
        finishedManager.finishedBooks.map {
            Book(title: $0.title, author: $0.author, cover: $0.cover, path: $0.path)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Home")
                                .font(.system(size: 38, weight: .bold, design: .serif))
                        }
                        
                        Spacer()
                        
                        // Circular Streak Ring Badge in Top Right
                        Button(action: {
                            showOnboardingSheet = true
                        }) {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                                    Circle()
                                        .trim(from: 0, to: CGFloat(goalsManager.progress))
                                        .stroke(Color.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                    
                                    Text("\(goalsManager.streakDays)\n\(goalsManager.dailyGoalMinutes)")
                                        .font(.system(size: 8, weight: .bold))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(width: 26, height: 26)
                            }
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .focusEffectDisabled()
                        .help("Adjust Reading Goals")
                        .padding(.trailing, 8)
                    }
                    .padding(.horizontal, 36)
                    .padding(.top, 24)
                    
                    // Continue Section
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Continue")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .padding(.horizontal, 36)
                        
                        if continueBooks.isEmpty {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("No Books in Progress")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("When you open and actively read a book from your Library, it will appear here.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                            .padding(.horizontal, 36)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 18) {
                                    ForEach(Array(continueBooks.enumerated()), id: \.element.title) { idx, book in
                                        Button(action: {
                                            ReaderWindowManager.shared.openReader(for: book)
                                        }) {
                                            HStack(spacing: 14) {
                                                BookCoverView(book: book, width: 68, showTitle: false)
                                                    .cornerRadius(6)
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(book.title)
                                                        .font(.system(size: 13, weight: .bold))
                                                        .lineLimit(2)
                                                        .foregroundColor(.primary)
                                                    
                                                    Text(book.author)
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                    
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "book.fill")
                                                            .font(.system(size: 9))
                                                            .foregroundColor(.secondary)
                                                        Text("In Progress")
                                                            .font(.system(size: 11))
                                                            .foregroundColor(.secondary)
                                                    }
                                                    .padding(.top, 4)
                                                }
                                                .frame(maxWidth: 160, alignment: .leading)
                                                
                                                Spacer(minLength: 0)
                                            }
                                            .padding(12)
                                            .frame(width: 270, height: 115)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color(nsColor: .controlBackgroundColor))
                                                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .focusable(false)
                                        .focusEffectDisabled()
                                        .contextMenu {
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
                                            
                                            Button(action: {
                                                readingManager.removeBook(book: book)
                                            }) {
                                                Label("Remove from Continue Reading", systemImage: "xmark.circle")
                                            }
                                            
                                            Divider()
                                            
                                            Button(action: {
                                                BooksViewModel.shared.hideBook(book: book)
                                            }) {
                                                Label("Hide Book", systemImage: "eye.slash")
                                            }
                                            
                                            Button(role: .destructive, action: {
                                                BooksViewModel.shared.removeBook(book: book)
                                            }) {
                                                Label("Remove from Collection", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 36)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    // 2. Want to Read Section
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Want to Read")
                                .font(.system(size: 22, weight: .bold, design: .serif))
                            Spacer()
                            Text("\(wantToReadManager.savedItems.count) Books")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 36)
                        
                        if wantToReadManager.savedItems.isEmpty {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("No Books Saved Yet")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Save books you want to read next from Browse or Book Store.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(20)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
                            .padding(.horizontal, 36)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 18) {
                                    ForEach(wantToReadManager.savedItems) { item in
                                        VStack(alignment: .leading, spacing: 6) {
                                            if let urlStr = item.coverURL, let url = URL(string: urlStr) {
                                                AsyncImage(url: url) { img in
                                                    img.resizable().aspectRatio(contentMode: .fill)
                                                } placeholder: {
                                                    Rectangle().fill(Color.gray.opacity(0.15))
                                                }
                                                .frame(width: 80, height: 120)
                                                .cornerRadius(6)
                                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                                            } else {
                                                Image(systemName: "book.closed")
                                                    .font(.system(size: 32))
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 80, height: 120)
                                                    .background(Color.gray.opacity(0.15))
                                                    .cornerRadius(6)
                                            }
                                            Text(item.title)
                                                .font(.system(size: 12, weight: .semibold))
                                                .lineLimit(2)
                                                .frame(width: 80, alignment: .leading)
                                            Text(item.author)
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .frame(width: 80, alignment: .leading)
                                        }
                                    }
                                }
                                .padding(.horizontal, 36)
                            }
                        }
                    }
                    
                    // 3. Previous (Finished / Previously Read Books)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Previous")
                                .font(.system(size: 22, weight: .bold, design: .serif))
                            Spacer()
                            Text("\(finishedBooks.count) Finished")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 36)
                        
                        if finishedBooks.isEmpty {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("No Completed Books Yet")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Books you finish reading will appear here as your reading history.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(20)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
                            .padding(.horizontal, 36)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 18) {
                                    ForEach(finishedBooks) { book in
                                        Button(action: {
                                            selectedBookForDetail = book
                                        }) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                ZStack(alignment: .bottomTrailing) {
                                                    BookCoverView(book: book, width: 80, showTitle: false)
                                                        .cornerRadius(6)
                                                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                                                    Circle()
                                                        .fill(Color.primary)
                                                        .frame(width: 18, height: 18)
                                                        .overlay(Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(Color(nsColor: .windowBackgroundColor)))
                                                        .offset(x: 4, y: 4)
                                                }
                                                Text(book.title)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .lineLimit(2)
                                                    .frame(width: 80, alignment: .leading)
                                                Text(book.author)
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                                    .frame(width: 80, alignment: .leading)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .focusable(false)
                                        .focusEffectDisabled()
                                    }
                                }
                                .padding(.horizontal, 36)
                            }
                        }
                    }
                    
                    // 4. Reading Goals Showcase Card (Authentic Apple Design)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Reading Goals")
                                    .font(.system(size: 22, weight: .bold, design: .serif))
                                Text("Read every day, see your stats soar and finish more books.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: {
                                showOnboardingSheet = true
                            }) {
                                Text("Edit Goal")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .focusEffectDisabled()
                        }
                        .padding(.horizontal, 36)
                        
                        VStack(spacing: 24) {
                            // Top Arc Gauge (Clean Apple Design)
                            ZStack {
                                // Background Arc Track
                                HalfCircleGauge()
                                    .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                    .frame(width: 340, height: 170)
                                    
                                // Neutral Progress Arc
                                HalfCircleGauge()
                                    .trim(from: 0, to: CGFloat(goalsManager.progress))
                                    .stroke(Color.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                    .frame(width: 340, height: 170)
                                    .animation(.easeInOut(duration: 0.4), value: goalsManager.progress)
                                
                                // Inner Metric Text
                                VStack(spacing: 6) {
                                    Text("Today’s Reading")
                                        .font(.system(size: 15, design: .serif))
                                        .foregroundColor(.secondary)
                                    
                                    Text(goalsManager.timeString)
                                        .font(.system(size: 52, weight: .bold, design: .serif))
                                    
                                    Text("of your \(goalsManager.dailyGoalMinutes)-minute goal")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                    
                                    // Solid Black Pill Button Matching Apple Books
                                    if let first = continueBooks.first {
                                        Button(action: {
                                            ReaderWindowManager.shared.openReader(for: first)
                                        }) {
                                            VStack(spacing: 2) {
                                                Text("Keep Reading")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(.white)
                                                Text(first.title)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(Color.white.opacity(0.8))
                                                    .lineLimit(1)
                                            }
                                            .padding(.horizontal, 32)
                                            .padding(.vertical, 10)
                                            .background(
                                                Capsule().fill(Color.black)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.top, 8)
                                    }
                                }
                                .padding(.top, 34)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 16)
                            
                            Rectangle()
                                .fill(Color.primary.opacity(0.18))
                                .frame(height: 1)
                                .padding(.horizontal, 20)
                            
                            // Weekday Streak Circles (Apple Books Parity: No strike-through line, contiguous streak segments only)
                            VStack(spacing: 12) {
                                StreakRowView(weekDays: goalsManager.weekDays, streakDays: goalsManager.streakDays)
                                
                                VStack(spacing: 2) {
                                    Text("Start a new streak.")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text("Your record is 10 days.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.bottom, 20)
                        }
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                        )
                        .padding(.horizontal, 36)
                    }
                    
                    // Books Read This Year Section (Only shown when books have actually been finished)
                    if !finishedBooks.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("Books Read This Year")
                                    .font(.system(size: 20, weight: .bold, design: .serif))
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 36)
                            
                            VStack(spacing: 20) {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 7), spacing: 14) {
                                    ForEach(finishedBooks) { book in
                                        Button(action: {
                                            selectedBookForDetail = book
                                        }) {
                                            ZStack(alignment: .bottomTrailing) {
                                                BookCoverView(book: book, width: 74, showTitle: false)
                                                    .cornerRadius(4)
                                                    .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 2)
                                                
                                                // Neutral Checkmark Badge
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.primary)
                                                        .frame(width: 18, height: 18)
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(Color(nsColor: .windowBackgroundColor))
                                                }
                                                .offset(x: 4, y: 4)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .focusable(false)
                                        .focusEffectDisabled()
                                    }
                                }
                                .padding(.top, 10)
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                            )
                            .padding(.horizontal, 36)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .sheet(item: $selectedBookForDetail) { book in
                BookDetailView(book: book)
            }
            .sheet(isPresented: $showOnboardingSheet) {
                ReadingGoalsOnboardingView()
            }
            .onAppear {
                if !goalsManager.hasCompletedOnboarding {
                    showOnboardingSheet = true
                }
            }
        }
    }
}

struct ReadingGoalsOnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var goalsManager = ReadingGoalsManager.shared
    
    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case goals = 1
        case aesthetic = 2
        case ready = 3
    }
    
    @State private var currentStep: OnboardingStep = .welcome
    @State private var selectedGoal: Int = 15
    @State private var selectedYearlyTarget: Int = 12
    @State private var selectedTheme: String = "Original"
    @State private var selectedFont: String = "Georgia"
    
    let goalOptions = [
        (5, "5 Min", "Quick daily pause"),
        (15, "15 Min", "Balanced daily habit"),
        (30, "30 Min", "Deep chapter focus"),
        (45, "45 Min", "Avid book lover"),
        (60, "60 Min", "Master reader")
    ]
    
    let yearlyOptions = [6, 12, 24, 52]
    
    let themes: [(String, Color, Color)] = [
        ("Original", Color.white, Color(hex: "#1C1C1E")),
        ("Quiet", Color(hex: "#2C2C2E"), Color(hex: "#E5E5EA")),
        ("Paper", Color(hex: "#F5EFE6"), Color(hex: "#3D2E1E")),
        ("Bold", Color(hex: "#000000"), Color.white),
        ("Calm", Color(hex: "#F8EFE4"), Color(hex: "#3D2F24")),
        ("Focus", Color(hex: "#EAEAEA"), Color(hex: "#1C1C1E"))
    ]
    
    let fontOptions = ["Georgia", "Charter", "San Francisco", "New York", "Palatino"]
    
    private var appIcon: NSImage? {
        let path = ("~/.books1_cache/icons/AppIcon_Coral.icns" as NSString).expandingTildeInPath
        if let img = NSImage(contentsOfFile: path) {
            return img
        }
        return NSApp.applicationIconImage
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation / Progress Indicator
            HStack {
                if currentStep.rawValue > 0 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) {
                                currentStep = prev
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 48)
                }
                
                Spacer()
                
                // Pagination dots
                HStack(spacing: 6) {
                    ForEach(OnboardingStep.allCases, id: \.self) { step in
                        Circle()
                            .fill(step == currentStep ? Color.primary : Color.secondary.opacity(0.25))
                            .frame(width: step == currentStep ? 7 : 5, height: step == currentStep ? 7 : 5)
                            .animation(.easeInOut(duration: 0.2), value: currentStep)
                    }
                }
                
                Spacer()
                
                if currentStep != .ready {
                    Button("Skip") {
                        goalsManager.completeOnboarding(goalMinutes: selectedGoal, yearlyTarget: selectedYearlyTarget, theme: selectedTheme, font: selectedFont)
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .focusEffectDisabled()
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                } else {
                    Spacer().frame(width: 48)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            
            // Step Content
            VStack {
                switch currentStep {
                case .welcome:
                    welcomeView
                case .goals:
                    goalsView
                case .aesthetic:
                    aestheticView
                case .ready:
                    readyView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Action Bar
            Divider()
            HStack {
                Text("Step \(currentStep.rawValue + 1) of 4")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if currentStep == .ready {
                            goalsManager.completeOnboarding(goalMinutes: selectedGoal, yearlyTarget: selectedYearlyTarget, theme: selectedTheme, font: selectedFont)
                            dismiss()
                        } else if let next = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                            currentStep = next
                        }
                    }
                }) {
                    Text(currentStep == .ready ? "Start Reading" : (currentStep == .welcome ? "Get Started" : "Continue"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(nsColor: .windowBackgroundColor))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.primary)
                        .cornerRadius(18)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 540, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // Step 1: Welcome View
    private var welcomeView: some View {
        VStack(spacing: 20) {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 76, height: 76)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
            } else {
                Image(systemName: "books.vertical.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.cyan)
            }
            
            VStack(spacing: 6) {
                Text("Welcome to Booksy")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                Text("Your private, high-fidelity library for EPUBs, PDFs, and books.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            VStack(alignment: .leading, spacing: 14) {
                featureRow(icon: "headphones", title: "Kokoro Neural TTS", desc: "Lifelike offline voice synthesis that reads chapters and PDF pages aloud seamlessly.")
                featureRow(icon: "doc.text.image", title: "Universal PDF & EPUB Reader", desc: "Dynamic in-memory page previews, fluid vector PDF rendering, and customizable typography.")
                featureRow(icon: "flame", title: "Daily Reading Streaks", desc: "Track daily minutes read, set yearly milestones, and build your reading streak.")
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
        }
        .padding(.horizontal, 24)
    }
    
    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
    }
    
    // Step 2: Goals View
    private var goalsView: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Build Your Daily Habit")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                Text("Choose how many minutes you want to read each day to keep your streak alive.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("DAILY TARGET")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                VStack(spacing: 7) {
                    ForEach(goalOptions, id: \.0) { min, title, desc in
                        Button(action: {
                            selectedGoal = min
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text(desc)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedGoal == min {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.primary)
                                        .font(.system(size: 17))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedGoal == min ? Color.primary.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedGoal == min ? Color.primary : Color.secondary.opacity(0.18), lineWidth: selectedGoal == min ? 1.5 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .focusEffectDisabled()
                    }
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("\(selectedGoal) min/day adds up to ~\(Int(Double(selectedGoal * 365) / 60.0)) hours of reading per year.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: 380)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("YEARLY TARGET")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                HStack(spacing: 12) {
                    ForEach(yearlyOptions, id: \.self) { num in
                        Button(action: {
                            selectedYearlyTarget = num
                        }) {
                            Text("\(num) Books")
                                .font(.system(size: 12, weight: selectedYearlyTarget == num ? .bold : .medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(selectedYearlyTarget == num ? Color.primary : Color(nsColor: .controlBackgroundColor))
                                )
                                .foregroundColor(selectedYearlyTarget == num ? Color(nsColor: .windowBackgroundColor) : .primary)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .focusEffectDisabled()
                    }
                }
            }
            .frame(maxWidth: 380)
        }
        .padding(.horizontal, 24)
    }
    
    // Step 3: Aesthetic View
    private var aestheticView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Reading Aesthetic")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                Text("Personalize page themes and typography to suit your reading comfort.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("PAGE THEME")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(themes, id: \.0) { name, bg, fg in
                        Button(action: {
                            selectedTheme = name
                        }) {
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(bg)
                                    .frame(height: 44)
                                    .overlay(
                                        VStack(spacing: 2) {
                                            Text("Aa")
                                                .font(.system(size: 15, weight: .bold, design: .serif))
                                                .foregroundColor(fg)
                                            Rectangle()
                                                .fill(fg.opacity(0.35))
                                                .frame(width: 22, height: 2)
                                                .cornerRadius(1)
                                        }
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedTheme == name ? Color.primary : Color.secondary.opacity(0.2), lineWidth: selectedTheme == name ? 2 : 1)
                                    )
                                    .shadow(color: Color.black.opacity(selectedTheme == name ? 0.08 : 0.02), radius: 3, x: 0, y: 1)
                                Text(name)
                                    .font(.system(size: 11, weight: selectedTheme == name ? .bold : .medium))
                                    .foregroundColor(selectedTheme == name ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .focusEffectDisabled()
                    }
                }
            }
            .frame(maxWidth: 380)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("TYPOGRAPHY")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(fontOptions, id: \.self) { fontName in
                            Button(action: {
                                selectedFont = fontName
                            }) {
                                Text(fontName)
                                    .font(.custom(fontName == "San Francisco" ? "-apple-system" : fontName, size: 12))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(selectedFont == fontName ? Color.primary : Color(nsColor: .controlBackgroundColor))
                                    )
                                    .foregroundColor(selectedFont == fontName ? Color(nsColor: .windowBackgroundColor) : .primary)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .focusEffectDisabled()
                        }
                    }
                }
            }
            .frame(maxWidth: 380)
            
            // Live Preview Card
            VStack(alignment: .leading, spacing: 6) {
                let activeTheme = themes.first(where: { $0.0 == selectedTheme }) ?? themes[0]
                VStack(alignment: .leading, spacing: 4) {
                    Text("The Great Gatsby")
                        .font(.custom(selectedFont == "San Francisco" ? "-apple-system" : selectedFont, size: 13))
                        .fontWeight(.bold)
                        .foregroundColor(activeTheme.2)
                    Text("In my younger and more vulnerable years my father gave me some advice that I’ve been turning over in my mind ever since.")
                        .font(.custom(selectedFont == "San Francisco" ? "-apple-system" : selectedFont, size: 11))
                        .foregroundColor(activeTheme.2.opacity(0.85))
                        .lineSpacing(3)
                }
                .padding(12)
                .frame(maxWidth: 380, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(activeTheme.1)
                        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            .frame(maxWidth: 380)
        }
        .padding(.horizontal, 24)
    }
    
    // Step 4: Ready View
    private var readyView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 76, height: 76)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 42))
                    .foregroundColor(.primary)
            }
            .padding(.top, 6)
            
            VStack(spacing: 6) {
                Text("You're All Set!")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                Text("Enjoying books and PDFs with Booksy is fast and simple.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 10) {
                tipCard(icon: "macwindow.badge.plus", title: "Open With Booksy", desc: "Right-click any .epub or .pdf in Finder and choose Open With -> Booksy, or double-click.")
                tipCard(icon: "books.vertical.fill", title: "Automatic Collection", desc: "Every book or PDF you open is automatically remembered in your Library.")
                tipCard(icon: "speaker.wave.3.fill", title: "Listen Anywhere", desc: "Tap the Read Aloud button in any chapter to enjoy hands-free neural narration.")
            }
            .frame(maxWidth: 380)
        }
        .padding(.horizontal, 24)
    }
    
    private func tipCard(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.primary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

struct HalfCircleGauge: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width / 2,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        return path
    }
}

struct StreakRowView: View {
    let weekDays: [(String, Bool)]
    let streakDays: Int
    
    // Apple Books streak dimensions and colors
    private let circleSize: CGFloat = 28.0
    private let strokeSize: CGFloat = 32.0
    private let lineHeight: CGFloat = 3.5
    private let streakBlue = Color(red: 0.0, green: 0.55, blue: 0.95)
    
    var body: some View {
        HStack(spacing: 0) {
            // Left lead-in buffer: only displays smooth gradient entry into Sunday
            // if Sunday is completed AND the streak extends from the previous week!
            if weekDays.first?.1 == true && streakDays > 1 {
                LinearGradient(
                    colors: [streakBlue.opacity(0.0), streakBlue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 22, height: lineHeight)
            } else {
                Spacer().frame(width: 22)
            }
            
            ForEach(0..<weekDays.count, id: \.self) { idx in
                let day = weekDays[idx]
                let isToday = (Calendar.current.component(.weekday, from: Date()) - 1) == idx
                let isCompleted = day.1
                let prevCompleted = (idx > 0) ? weekDays[idx - 1].1 : false
                let nextCompleted = (idx < weekDays.count - 1) ? weekDays[idx + 1].1 : false
                
                ZStack {
                    // Center-running horizontal streak track passing BEHIND the circle
                    // The line is drawn continuously between adjacent completed days ONLY.
                    // If a day is missed or the streak breaks, the line halts completely!
                    HStack(spacing: 0) {
                        // Left half: from left edge of cell to circle center
                        if idx == 0 {
                            // Sunday: connects from the lead-in to center if continuing from last week
                            if isCompleted && streakDays > 1 {
                                Rectangle()
                                    .fill(streakBlue)
                                    .frame(height: lineHeight)
                            } else {
                                Spacer().frame(height: lineHeight)
                            }
                        } else {
                            // Days 1..6: connects from left edge to center ONLY if both prev day and this day are completed
                            if isCompleted && prevCompleted {
                                Rectangle()
                                    .fill(streakBlue)
                                    .frame(height: lineHeight)
                            } else {
                                Spacer().frame(height: lineHeight)
                            }
                        }
                        
                        // Right half: from circle center to right edge of cell
                        if idx < weekDays.count - 1 {
                            // Connects from center to right edge ONLY if both this day and next day are completed
                            if isCompleted && nextCompleted {
                                Rectangle()
                                    .fill(streakBlue)
                                    .frame(height: lineHeight)
                            } else {
                                Spacer().frame(height: lineHeight)
                            }
                        } else {
                            // Saturday: end of the week
                            Spacer().frame(height: lineHeight)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Day Circle Node (centered directly on top of the track)
                    ZStack {
                        if isCompleted {
                            // Completed day in streak: Apple Books vibrant blue filled circle
                            Circle()
                                .fill(streakBlue)
                                .frame(width: circleSize, height: circleSize)
                            Text(day.0)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        } else if isToday {
                            // Current day in progress (clean background mask + Primary ring border)
                            Circle()
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .frame(width: strokeSize, height: strokeSize)
                            Circle()
                                .stroke(Color.primary, lineWidth: 2.2)
                                .frame(width: strokeSize, height: strokeSize)
                            Text(day.0)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.primary)
                        } else {
                            // Inactive or future day (masking background so the track doesn't bleed through)
                            Circle()
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .frame(width: circleSize, height: circleSize)
                            Circle()
                                .fill(Color.primary.opacity(0.14))
                                .frame(width: circleSize, height: circleSize)
                            Text(day.0)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.primary.opacity(0.65))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // Right buffer
            Spacer().frame(width: 22)
        }
        .frame(maxWidth: 380)
    }
}

