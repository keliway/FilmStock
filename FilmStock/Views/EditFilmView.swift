//
//  EditFilmView.swift
//  FilmStock
//
//  Edit film view (iOS Form style)
//

import SwiftUI

struct EditFilmView: View {
    let groupedFilm: GroupedFilm
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: FilmStockDataManager
    
    @State private var name = ""
    @State private var manufacturer = ""
    @State private var type: FilmStock.FilmType = .bw
    @State private var filmSpeed = 400
    
    private let isoValues = [1, 2, 4, 5, 8, 10, 12, 16, 20, 25, 32, 40, 50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200, 6400]
    @State private var format: FilmStock.FilmFormat = .thirtyFive
    @State private var quantity = 0
    @State private var expireDates: [String] = [""]
    @State private var comments = ""
    @State private var filmToEdit: FilmStock?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Film Information") {
                    NavigationLink {
                        ManufacturerPickerView(
                            selectedManufacturer: $manufacturer
                        )
                        .environmentObject(dataManager)
                    } label: {
                        Text(manufacturer.isEmpty ? "Select Manufacturer" : manufacturer)
                            .foregroundColor(manufacturer.isEmpty ? .secondary : .primary)
                    }
                    
                    TextField("Name", text: $name)
                    
                    Picker("Type", selection: $type) {
                        ForEach(FilmStock.FilmType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    Picker("Speed", selection: $filmSpeed) {
                        ForEach(isoValues, id: \.self) { iso in
                            Text("ISO \(iso)").tag(iso)
                        }
                    }
                    .pickerStyle(.wheel)
                    
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
            .navigationTitle("Edit Film")
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
            .onAppear {
                loadFilmToEdit()
            }
        }
    }
    
    private func loadFilmToEdit() {
        // Find the first matching FilmStock from the groupedFilm
        // Use the first format's ID to find the matching film
        if let firstFormat = groupedFilm.formats.first {
            filmToEdit = dataManager.filmStocks.first { $0.id == firstFormat.id }
        }
        
        // If not found, try to find by matching criteria
        if filmToEdit == nil {
            filmToEdit = dataManager.filmStocks.first { film in
                film.name == groupedFilm.name &&
                film.manufacturer == groupedFilm.manufacturer &&
                film.type == groupedFilm.type &&
                film.filmSpeed == groupedFilm.filmSpeed
            }
        }
        
        // Pre-fill with existing film data
        if let film = filmToEdit {
            name = film.name
            manufacturer = film.manufacturer
            type = film.type
            filmSpeed = film.filmSpeed
            format = film.format
            quantity = film.quantity
            expireDates = film.expireDate ?? [""]
            if expireDates.isEmpty {
                expireDates = [""]
            }
            comments = film.comments ?? ""
        } else {
            // Fallback to groupedFilm data if no FilmStock found
            name = groupedFilm.name
            manufacturer = groupedFilm.manufacturer
            type = groupedFilm.type
            filmSpeed = groupedFilm.filmSpeed
            if let firstFormat = groupedFilm.formats.first {
                format = firstFormat.format
                quantity = firstFormat.quantity
                expireDates = firstFormat.expireDate ?? [""]
                if expireDates.isEmpty {
                    expireDates = [""]
                }
            }
        }
    }
    
    private func saveFilm() {
        let filteredDates = expireDates.filter { !$0.isEmpty }
        
        if let existingFilm = filmToEdit {
            // Update existing film - create new instance with updated values
            let updated = FilmStock(
                id: existingFilm.id,
                name: name,
                manufacturer: manufacturer,
                type: type,
                filmSpeed: filmSpeed,
                format: format,
                quantity: quantity,
                expireDate: filteredDates.isEmpty ? nil : filteredDates,
                comments: comments.isEmpty ? nil : comments,
                createdAt: existingFilm.createdAt,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            
            dataManager.updateFilmStock(updated)
            dismiss()
        } else {
            // If no film found, create a new one (shouldn't happen, but handle it)
            let film = FilmStock(
                id: UUID().uuidString,
                name: name,
                manufacturer: manufacturer,
                type: type,
                filmSpeed: filmSpeed,
                format: format,
                quantity: quantity,
                expireDate: filteredDates.isEmpty ? nil : filteredDates,
                comments: comments.isEmpty ? nil : comments,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: nil
            )
            
            Task {
                let wasUpdated = await dataManager.addFilmStock(film)
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
}

