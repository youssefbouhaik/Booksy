//
//  SectionsDetailView.swift
//  Books
//
//  Created by Matthew Andrea D'Alessio on 15/11/23.
//

import SwiftUI

struct SectionsDetailView: View {
    
    init(category: String) {
#if canImport(UIKit)
        UILabel.appearance(whenContainedInInstancesOf: [UINavigationBar.self]).adjustsFontSizeToFitWidth = true
#endif
        self.category = category
#if canImport(UIKit)
        UINavigationBar.appearance().largeTitleTextAttributes = [.font : UIFont(name: "Georgia-Bold", size: 34)!]
        UINavigationBar.appearance().titleTextAttributes = [.font : UIFont(name: "Georgia-Bold", size: 19)!]
#endif
    }
    
    @State private var selectedBook: Book?
    
    var filteredBooks1: [Book] {
        return BooksViewModel.books1.filter { $0.categories.contains(category) }
    }
    
    var filteredBooks4: [Book] {
        return BooksViewModel.books4.filter { $0.categories.contains(category) }
    }
    
    var filteredBooksHaveYouRead: [Book] {
        return BooksViewModel.books2.filter { $0.categories.contains(category) } + BooksViewModel.books3.filter { $0.categories.contains(category) } + BooksViewModel.books5.filter { $0.categories.contains(category) } + BooksViewModel.books1.filter { $0.categories.contains(category) } + BooksViewModel.books4.filter { $0.categories.contains(category) }
    }
    
    var category: String
    
    var body: some View {
        
        ScrollView {
            Divider()
                .padding(.horizontal, 24)
            
            VStack (alignment: .leading) {
                Text ("New Releases")
                    .font(Font.custom("Georgia-Bold", size: 21))
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                    .accessibilityLabel("New released books")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(filteredBooks1 + filteredBooks4) { book in
                        Button(action: {
                            selectedBook = book
                        }) {
                            BookCoverView(book: book, width: 140)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
            .padding(.bottom, 20)
            
            VStack {
                Divider()
                    .padding(.horizontal, 24)
                
                Button {
                    // No action
                } label: {
                    HStack {
                        Text("See All")
                            .font(.subheadline)
                        
                        Image(systemName: "chevron.forward")
                            .imageScale(.small)
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("See All")
                    .accessibilityHint("Double tap to see all books")
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 30)
            }
            
            VStack {
                VStack (alignment: .leading) {
                    Text ("Have You Read...?")
                        .font(Font.custom("Georgia-Bold", size: 21))
                        .foregroundColor(Color.white)
                        .padding(.top, 30)
                        .padding(.bottom, 20)
                        .accessibilityLabel("Have you read these books?")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [GridItem(.flexible())], spacing: 0) {
                        ForEach(filteredBooksHaveYouRead) { book in
                            Button(action: {
                                selectedBook = book
                            }) {
                                Image(book.cover)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .cornerRadius(5)
                                    .frame(height: 220)
                                    .padding(.horizontal)
                                    .accessibilityLabel("Cover of \(book.title)")
                                    .accessibilityHint("Double tap to see the details or read the book or swipe horizontally with three fingers to explore more books")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .frame(maxHeight: 220)
                    
                }
                .padding(.bottom, 20)
                
                VStack {
                    Button {
                        // No action
                    } label: {
                        HStack {
                            Text("See All")
                                .foregroundColor(.white)
                                .font(.subheadline)

                            Image(systemName: "chevron.forward")
                                .imageScale(.small)
                                .foregroundColor(.gray)
                            
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("See All")
                        .accessibilityHint("Double tap to see all books")
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 30)
                }
            }
            .background(LinearGradient(gradient: Gradient(colors: [Color("MyColor"), Color("MyColor").opacity(0.6)]), startPoint: .top, endPoint: .bottom))
            
            .navigationTitle(category)
            Spacer()
        }
        .sheet(item: $selectedBook) { selectedBook in
            BookDetailView(book: selectedBook)
        }
    }
}

struct SectionsDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SectionsDetailView(category: "Top Charts")
        }
    }
}
