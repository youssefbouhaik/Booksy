//
//  ReadingGoalsManager.swift
//  Folio / Books
//

import Foundation
import Combine

class ReadingGoalsManager: ObservableObject {
    static let shared = ReadingGoalsManager()
    
    @Published var dailyGoalMinutes: Int = 5
    @Published var yearlyBooksTarget: Int = 12
    @Published var todaySecondsRead: Int = 0
    @Published var streakDays: Int = 0
    @Published var hasCompletedOnboarding: Bool = false
    @Published var weekDays: [(String, Bool)] = [
        ("S", false),
        ("M", false),
        ("T", false),
        ("W", false),
        ("T", false),
        ("F", false),
        ("S", false)
    ]
    @Published var lastReadDate: Date? = nil
    
    private let cacheFile: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".books1_cache")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("reading_goals.json")
    }()
    
    var progress: Double {
        let targetSec = Double(max(1, dailyGoalMinutes * 60))
        return min(1.0, Double(todaySecondsRead) / targetSec)
    }
    
    var timeString: String {
        let mins = todaySecondsRead / 60
        let secs = todaySecondsRead % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    init() {
        load()
        checkDayRollover()
    }
    
    func checkDayRollover() {
        guard let last = lastReadDate else { return }
        let calendar = Calendar.current
        if !calendar.isDateInToday(last) {
            // Check if last read was yesterday
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()),
               calendar.isDate(last, inSameDayAs: yesterday) {
                // If yesterday's goal was not met, the streak halts
                if todaySecondsRead < dailyGoalMinutes * 60 {
                    streakDays = 0
                }
            } else {
                // Missed one or more days: streak halts to 0
                streakDays = 0
            }
            
            // Check if it's a new week (Sunday)
            let todayWeekday = calendar.component(.weekday, from: Date())
            if todayWeekday == 1 {
                // Reset week days on Sunday
                weekDays = [
                    ("S", false), ("M", false), ("T", false),
                    ("W", false), ("T", false), ("F", false), ("S", false)
                ]
            }
            
            todaySecondsRead = 0
            save()
        }
    }
    
    func resetToZero() {
        todaySecondsRead = 0
        streakDays = 0
        yearlyBooksTarget = 12
        hasCompletedOnboarding = false
        weekDays = [
            ("S", false),
            ("M", false),
            ("T", false),
            ("W", false),
            ("T", false),
            ("F", false),
            ("S", false)
        ]
        lastReadDate = nil
        save()
    }
    
    func completeOnboarding(goalMinutes: Int, yearlyTarget: Int = 12, theme: String = "Original", font: String = "Georgia") {
        self.dailyGoalMinutes = goalMinutes
        self.yearlyBooksTarget = yearlyTarget
        self.todaySecondsRead = 0
        self.streakDays = 0
        self.hasCompletedOnboarding = true
        self.lastReadDate = Date()
        UserDefaults.standard.set(theme, forKey: "ReaderTheme")
        UserDefaults.standard.set(font, forKey: "ReaderFont")
        save()
    }
    
    func addSeconds(_ seconds: Int) {
        checkDayRollover()
        todaySecondsRead += seconds
        lastReadDate = Date()
        
        let goalSec = dailyGoalMinutes * 60
        if todaySecondsRead >= goalSec {
            let weekdayIdx = Calendar.current.component(.weekday, from: Date()) - 1
            if weekdayIdx >= 0 && weekdayIdx < weekDays.count && !weekDays[weekdayIdx].1 {
                weekDays[weekdayIdx].1 = true
                streakDays = max(1, streakDays + 1)
            }
        }
        save()
    }
    
    private func load() {
        guard let data = try? Data(contentsOf: cacheFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            resetToZero()
            return
        }
        self.dailyGoalMinutes = json["dailyGoalMinutes"] as? Int ?? 5
        self.yearlyBooksTarget = json["yearlyBooksTarget"] as? Int ?? 12
        self.todaySecondsRead = json["todaySecondsRead"] as? Int ?? 0
        self.streakDays = json["streakDays"] as? Int ?? 0
        self.hasCompletedOnboarding = json["hasCompletedOnboarding"] as? Bool ?? false
        
        if let lastStr = json["lastReadDate"] as? String,
           let date = ISO8601DateFormatter().date(from: lastStr) {
            self.lastReadDate = date
        }
        
        if let daysArray = json["weekDays"] as? [[Any]] {
            var loaded: [(String, Bool)] = []
            for item in daysArray {
                if item.count == 2, let s = item[0] as? String, let b = item[1] as? Bool {
                    loaded.append((s, b))
                }
            }
            if loaded.count == 7 {
                self.weekDays = loaded
            }
        }
    }
    
    private func save() {
        var daysArray: [[Any]] = []
        for (s, b) in weekDays {
            daysArray.append([s, b])
        }
        var dict: [String: Any] = [
            "dailyGoalMinutes": dailyGoalMinutes,
            "yearlyBooksTarget": yearlyBooksTarget,
            "todaySecondsRead": todaySecondsRead,
            "streakDays": streakDays,
            "hasCompletedOnboarding": hasCompletedOnboarding,
            "weekDays": daysArray
        ]
        if let last = lastReadDate {
            dict["lastReadDate"] = ISO8601DateFormatter().string(from: last)
        }
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) {
            try? data.write(to: cacheFile)
        }
    }
}
