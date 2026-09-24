//
//  CustomizeThemeSheetView.swift
//  Folio / Books
//
//  Native Apple Books "Customize Theme" Modal Sheet with full typography and layout controls
//

import SwiftUI
import AppKit

struct CustomizeThemeSheetView: View {
    @Binding var isPresented: Bool
    @Binding var selectedFontFamily: String
    @Binding var isBoldText: Bool
    @Binding var isCustomizeEnabled: Bool
    @Binding var readerTheme: String
    @Binding var lineSpacing: Double
    @Binding var characterSpacing: Double
    @Binding var wordSpacing: Double
    @Binding var marginScale: Double
    @Binding var columnsOption: String
    @Binding var justifyText: Bool
    let fontFamilies: [String]
    
    @State private var showingFontPicker: Bool = false
    
    private func fontDisplayName(_ f: String) -> String {
        if f == "-apple-system" || f == "San Francisco" {
            return "San Francisco"
        }
        return f
    }
    
    private var previewHeaderFont: Font {
        if selectedFontFamily == "San Francisco" || selectedFontFamily == "-apple-system" {
            return .system(size: 34, weight: isBoldText ? .black : .bold, design: .default)
        } else {
            return .system(size: 34, weight: isBoldText ? .heavy : .bold, design: .serif)
        }
    }
    
    private var previewBodyFont: Font {
        let weight: Font.Weight = isBoldText ? .semibold : .regular
        if selectedFontFamily == "San Francisco" || selectedFontFamily == "-apple-system" {
            return .system(size: 13.5, weight: weight, design: .default)
        } else if selectedFontFamily == "Original" {
            return .system(size: 13.5, weight: weight, design: .serif)
        } else {
            return .custom(selectedFontFamily, size: 13.5)
        }
    }
    
    private func fontForPreview(_ f: String, size: CGFloat) -> Font {
        if f == "San Francisco" || f == "-apple-system" {
            return .system(size: size, weight: .regular, design: .default)
        } else if f == "Original" {
            return .system(size: size, weight: .regular, design: .serif)
        } else {
            return .custom(f, size: size)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Nav Header Bar (Matching Apple Books)
            HStack {
                if showingFontPicker {
                    Button(action: { showingFontPicker = false }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                } else {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary.opacity(0.75))
                            .frame(width: 30, height: 30)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
                
                Spacer()
                
                Text(showingFontPicker ? "Font" : "Customize Theme")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if showingFontPicker {
                    Button(action: { showingFontPicker = false }) {
                        Text("Done")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                } else {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)
            
            if showingFontPicker {
                // Font Selection List
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(fontFamilies, id: \.self) { fontName in
                            Button(action: {
                                selectedFontFamily = fontName
                                showingFontPicker = false
                            }) {
                                HStack {
                                    Text(fontDisplayName(fontName))
                                        .font(fontForPreview(fontName, size: 15))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedFontFamily == fontName {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            if fontName != fontFamilies.last {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .cornerRadius(12)
                    .padding(20)
                }
            } else {
                // Top Live Typography Preview Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Aa")
                        .font(previewHeaderFont)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    
                    Text("It is my opinion that lots would escape from slavery, who now remain, however for the strong cords of love that bind them to their friends. The idea of leaving my pals turned into decidedly the most painful concept with which I needed to contend. The love of them become my tender point, and shook my selection more than all matters else. Besides the pain of separation, the dread and apprehension of a failure handed what I had skilled at my first try. The appalling defeat I then sustained back to torment me. I felt confident that, if I failed in this attempt, my case could be a hopeless one—it might seal my fate as a slave all the time.")
                        .font(previewBodyFont)
                        .foregroundColor(.primary)
                        .lineSpacing(3.8)
                        .padding(.horizontal, 24)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0.0),
                                    .init(color: .black, location: 0.72),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .frame(height: 220, alignment: .topLeading)
                
                Divider()
                
                // Form Options matching Apple Books Theme Customization
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        // Section: Text
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Text")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.leading, 14)
                            
                            VStack(spacing: 0) {
                                // Font Row
                                Button(action: { showingFontPicker = true }) {
                                    HStack(spacing: 12) {
                                        Text("Aa")
                                            .font(.system(size: 15, weight: .semibold, design: .serif))
                                            .frame(width: 22)
                                        Text("Font")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(fontDisplayName(selectedFontFamily))
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary.opacity(0.6))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                Divider().padding(.leading, 48)
                                
                                // Bold Text Row
                                HStack(spacing: 12) {
                                    Text("B")
                                        .font(.system(size: 15, weight: .black, design: .serif))
                                        .frame(width: 22)
                                    Text("Bold Text")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Toggle("", isOn: $isBoldText)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                            }
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                            .cornerRadius(12)
                        }
                        
                        // Section: Layout
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Layout")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.leading, 14)
                            
                            VStack(spacing: 0) {
                                // Line Spacing
                                VStack(spacing: 4) {
                                    HStack {
                                        Image(systemName: "text.line.spacing")
                                            .font(.system(size: 13))
                                            .frame(width: 22)
                                        Text("Line Spacing")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(String(format: "%.2f", lineSpacing))
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                    }
                                    Slider(value: $lineSpacing, in: 1.0...3.0, step: 0.05)
                                        .controlSize(.small)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                
                                Divider().padding(.leading, 48)
                                
                                // Character Spacing
                                VStack(spacing: 4) {
                                    HStack {
                                        Image(systemName: "character.textbox")
                                            .font(.system(size: 13))
                                            .frame(width: 22)
                                        Text("Character Spacing")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(Int(characterSpacing))%")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                    }
                                    Slider(value: $characterSpacing, in: -5...15, step: 1)
                                        .controlSize(.small)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                
                                Divider().padding(.leading, 48)
                                
                                // Word Spacing
                                VStack(spacing: 4) {
                                    HStack {
                                        Image(systemName: "textformat.abc")
                                            .font(.system(size: 13))
                                            .frame(width: 22)
                                        Text("Word Spacing")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(Int(wordSpacing))%")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                    }
                                    Slider(value: $wordSpacing, in: -5...15, step: 1)
                                        .controlSize(.small)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                
                                Divider().padding(.leading, 48)
                                
                                // Margins
                                VStack(spacing: 4) {
                                    HStack {
                                        Image(systemName: "arrow.left.and.right")
                                            .font(.system(size: 13))
                                            .frame(width: 22)
                                        Text("Margins")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(Int(marginScale))%")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                    }
                                    Slider(value: $marginScale, in: 0...50, step: 5)
                                        .controlSize(.small)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                
                                Divider().padding(.leading, 48)
                                
                                // Columns
                                HStack(spacing: 12) {
                                    Image(systemName: "rectangle.split.2x1")
                                        .font(.system(size: 13))
                                        .frame(width: 22)
                                    Text("Columns")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Picker("", selection: $columnsOption) {
                                        Text("Auto").tag("auto")
                                        Text("1").tag("1")
                                        Text("2").tag("2")
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 140)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                
                                Divider().padding(.leading, 48)
                                
                                // Justify Text
                                HStack(spacing: 12) {
                                    Image(systemName: "text.justify.left")
                                        .font(.system(size: 13))
                                        .frame(width: 22)
                                    Text("Justify Text")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Toggle("", isOn: $justifyText)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                
                                Divider().padding(.leading, 48)
                                
                                // Customize toggle
                                HStack(spacing: 12) {
                                    Image(systemName: "paintbrush")
                                        .font(.system(size: 13))
                                        .frame(width: 22)
                                    Text("Customize")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Toggle("", isOn: $isCustomizeEnabled)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                            }
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                            .cornerRadius(12)
                        }
                        
                        // Section: Reset Theme Button
                        Button(action: {
                            selectedFontFamily = "Original"
                            isBoldText = false
                            isCustomizeEnabled = true
                            readerTheme = "Original"
                            lineSpacing = 1.74
                            characterSpacing = 0.0
                            wordSpacing = 0.0
                            marginScale = 0.0
                            columnsOption = "auto"
                            justifyText = true
                        }) {
                            Text("Reset Theme")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(width: 440, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
