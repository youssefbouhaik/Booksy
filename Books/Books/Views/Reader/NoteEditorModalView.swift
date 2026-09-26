//
//  NoteEditorModalView.swift
//  Books
//
//  Apple Books-grade focused floating note and highlight editor.
//

import SwiftUI
import AppKit

struct NoteEditorState: Identifiable {
    let id = UUID()
    var noteId: UUID? = nil
    var quoteText: String
    var noteText: String
    var colorHex: String
    var pageNumber: Int
    var chapterIndex: Int
    var isPDF: Bool
}

struct NoteEditorModalView: View {
    let state: NoteEditorState
    var onSave: (String, String, String) -> Void
    var onDelete: (() -> Void)? = nil
    var onCancel: () -> Void
    
    @State private var currentNote: String = ""
    @State private var currentColor: String = "#FFD60A"
    @FocusState private var isEditorFocused: Bool
    
    let palette: [(name: String, hex: String)] = [
        ("Yellow", "#FFD60A"),
        ("Green", "#32D74B"),
        ("Blue", "#0A84FF"),
        ("Pink", "#FF375F"),
        ("Purple", "#BF5AF2")
    ]
    
    var body: some View {
        ZStack {
            // Dismissable dimmed backdrop
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // Centered sleek Card
            VStack(alignment: .leading, spacing: 14) {
                // Header: Note icon, Title, Page indicator, Close button
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: currentColor))
                    
                    Text(state.noteId != nil ? "Edit Note" : "Add Note")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("• Page \(state.pageNumber)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Color chips
                    HStack(spacing: 6) {
                        ForEach(palette, id: \.hex) { chip in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    currentColor = chip.hex
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: chip.hex))
                                        .frame(width: 16, height: 16)
                                    
                                    if currentColor.lowercased() == chip.hex.lowercased() {
                                        Circle()
                                            .stroke(Color.primary.opacity(0.85), lineWidth: 1.5)
                                            .frame(width: 20, height: 20)
                                    }
                                }
                                .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.plain)
                            .help("\(chip.name) Highlight")
                        }
                    }
                    
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Close (Esc)")
                }
                
                // Quote block preview
                if !state.quoteText.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(hex: currentColor))
                            .frame(width: 3)
                        
                        Text("\"\(state.quoteText)\"")
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: currentColor).opacity(0.08))
                    .cornerRadius(6)
                }
                
                // Note input text area
                VStack(alignment: .leading, spacing: 4) {
                    TextEditor(text: $currentNote)
                        .focused($isEditorFocused)
                        .font(.system(size: 13))
                        .lineSpacing(3)
                        .frame(minHeight: 88, maxHeight: 140)
                        .padding(6)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                }
                
                // Footer buttons
                HStack(spacing: 10) {
                    if state.noteId != nil || !state.quoteText.isEmpty {
                        Button(action: {
                            onDelete?()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                Text("Delete")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.red.opacity(0.85))
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                        }
                        .buttonStyle(.plain)
                        .help("Delete Note and Highlight")
                    }
                    
                    Spacer()
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    
                    Button(action: {
                        onSave(state.quoteText, currentNote, currentColor)
                    }) {
                        Text("Save Note")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.16, green: 0.50, blue: 0.98))
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(18)
            .frame(width: 440)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
        }
        .onAppear {
            currentNote = state.noteText
            currentColor = state.colorHex.isEmpty ? "#FFE270" : state.colorHex
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isEditorFocused = true
            }
        }
    }
}
