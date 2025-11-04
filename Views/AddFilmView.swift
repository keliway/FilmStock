//
//  AddFilmView.swift
//  FilmStock
//
//  Add/Edit film view (iOS Form style)
//

import SwiftUI

struct AddFilmView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: FilmStockDataManager
    
    @State private var name = ""
    @State private var manufacturer = ""
    @State private var type: FilmStock.FilmType = .bw
    @State private var filmSpeed = 400
    @State private var format: FilmStock.FilmFormat = .thirtyFive
    @State private var quantity = 0
    @State private var expireDates: [String] = [""]
    @State private var comments = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Film Information") {
                    TextField("Name", text: $name)
                    TextField("Manufacturer", text: $manufacturer)
                    
                    Picker("Type", selection: $type) {
                        ForEach(FilmStock.FilmType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    Stepper("Speed: ISO \(filmSpeed)", value: $filmSpeed, in: 25...3200, step: 25)
                    
                    Picker("Format", selection: $format) {
                        ForEach(FilmStock.FilmFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                }
                
                Section("Quantity") {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 0...999)
                }
                
                Section("Expire Dates") {
                    ForEach(expireDates.indices, id: \.self) { index in
                        TextField("MM/YYYY or YYYY", text: Binding(
                            get: { expireDates[index] },
                            set: { expireDates[index] = $0 }
                        ))
                    }
                    .onDelete { indexSet in
                        expireDates.remove(atOffsets: indexSet)
                    }
                    
                    Button("Add Date") {
                        expireDates.append("")
                    }
                }
                
                Section("Comments") {
                    TextEditor(text: $comments)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Film")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveFilm()
                    }
                    .disabled(name.isEmpty || manufacturer.isEmpty)
                }
            }
        }
    }
    
    private func saveFilm() {
        let film = FilmStock(
            id: UUID().uuidString,
            name: name,
            manufacturer: manufacturer,
            type: type,
            filmSpeed: filmSpeed,
            format: format,
            quantity: quantity,
            expireDate: expireDates.filter { !$0.isEmpty },
            comments: comments.isEmpty ? nil : comments,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: nil
        )
        
        dataManager.addFilmStock(film)
        dismiss()
    }
}

