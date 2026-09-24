//
//  BrowseSectionsView.swift
//  Books
//
//  Created by Matthew Andrea D'Alessio on 14/11/23.
//

import SwiftUI

struct BrowseSectionsView: View {
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    #if canImport(UIKit)
    init() {
            UINavigationBar.appearance().largeTitleTextAttributes = [.font : UIFont(name: "Georgia-Bold", size: 34)!]
            UINavigationBar.appearance().titleTextAttributes = [.font : UIFont(name: "Georgia-Bold", size: 19)!]
        }
#endif
    
    var viewModel = SectionsViewModel()
    
    var body: some View {
        
            List {
                ForEach(viewModel.sections.prefix(2)) { section in
                    NavigationLink(destination: SectionsDetailView(category: section.category)) {
                        HStack {
                            Image(systemName: section.emoji)
                                .imageScale(.large)
                                .frame(width: 40, height: 40)
                            Text(section.category)
                        }
                        .frame(height: 40)
                    }
                }
                
                Text("GENRES")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .padding(.vertical, 10)
                    .accessibilityLabel("Genres list")
                
                ForEach(viewModel.sections.dropFirst(2)) { section in
                    NavigationLink(destination: SectionsDetailView(category: section.category)) {
                        HStack {
                            Image(systemName: section.emoji)
                                .imageScale(.large)
                                .frame(width: 40, height: 40)
                            Text(section.category)
                        }
                        .frame(height: 40)
                    }
                }
            }
            .listStyle(InsetListStyle())
#if os(macOS)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "chevron.backward")
                                .font(Font.system(size: 16).weight(.bold))
                            Text("Book Store")
                        }
                    }
                }
            }
#else
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading:
                                    Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Image(systemName: "chevron.backward")
                        .font(Font.system(size: 16).weight(.bold))
                        .padding(.leading, -8)
                    Text("Book Store")
                        .padding(.leading, -2)
                }
            }
            )
#endif
        .navigationTitle("Browse Sections")
    }
}

struct BrowseSectionsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BrowseSectionsView()
        }
    }
}
