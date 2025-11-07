//
//  LoadedFilmsWidget.swift
//  FilmStockWidget
//
//  Widget to display loaded films
//

import WidgetKit
import SwiftUI
import SwiftData
import Foundation
import AppIntents

extension View {
    @ViewBuilder func widgetBackground<T: View>(@ViewBuilder content: () -> T) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget, content: content)
        } else {
            background(content())
        }
    }
}

struct LoadedFilmsWidget: Widget {
    let kind: String = "LoadedFilmsWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: LoadedFilmsWidgetConfiguration.self, provider: LoadedFilmsTimelineProvider()) { entry in
            LoadedFilmsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(Text("widget.title"))
        .description(Text("widget.description"))
        .supportedFamilies([.systemSmall])
    }
}

struct LoadedFilmsWidgetEntry: TimelineEntry {
    let date: Date
    let loadedFilms: [LoadedFilmWidgetData]
    let currentIndex: Int
    let configuration: LoadedFilmsWidgetConfiguration
}

struct LoadedFilmWidgetData: Identifiable {
    let id: String
    let filmName: String
    let manufacturer: String
    let format: String
    let camera: String
    let imageData: Data?
    let loadedAt: Date?
    
    var formatDisplayName: String {
        // Format display name mapping
        switch format {
        case "35": return "35mm"
        case "120": return "120"
        case "110": return "110"
        case "127": return "127"
        case "220": return "220"
        case "4x5": return "4x5"
        case "5x7": return "5x7"
        case "8x10": return "8x10"
        case "Other": return "Other"
        default: return format
        }
    }
    
    var loadedDateString: String {
        guard let loadedAt = loadedAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: loadedAt)
    }
}

struct LoadedFilmsWidgetEntryView: View {
    var entry: LoadedFilmsWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        // Only support systemSmall size
        if family != .systemSmall {
            Text("widget.unsupportedSize")
                .font(.caption)
                .foregroundColor(.secondary)
                .widgetBackground {
                    Color.clear
                }
        } else if entry.loadedFilms.isEmpty {
            EmptyWidgetView()
                .widgetBackground {
                    Color.clear
                }
                .widgetURL(URL(string: "filmstock://loadedfilms"))
        } else {
            // Show current film based on index
            let filmIndex = min(entry.currentIndex, entry.loadedFilms.count - 1)
            let film = entry.loadedFilms[max(0, filmIndex)]
            let hasMultiple = entry.loadedFilms.count > 1
            
            if let imageData = film.imageData,
               let uiImage = UIImage(data: imageData) {
                ZStack {
                    Color.clear
                        .widgetBackground {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        }
                    
                    // Film info bar (date and format) - conditionally shown and positioned
                    if entry.configuration.showFilmInfo ?? false {
                        VStack {
                            if (entry.configuration.infoPosition ?? .top) == .top {
                                // Top position
                                HStack {
                                    // Camera on the left
                                    if !film.camera.isEmpty {
                                        Text(film.camera)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                            .padding(.leading, 8)
                                    }
                                    
                                    Spacer()
                                    
                                    // Format chip on the right
                                    Text(film.formatDisplayName)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white)
                                        )
                                        .padding(.trailing, 8)
                                }
                                .padding(.top, 0)
                            }
                            
                            Spacer()
                            
                            if (entry.configuration.infoPosition ?? .top) == .bottom {
                                // Bottom position
                                HStack {
                                    // Camera on the left
                                    if !film.camera.isEmpty {
                                        Text(film.camera)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                            .padding(.leading, 8)
                                    }
                                    
                                    Spacer()
                                    
                                    // Format chip on the right
                                    Text(film.formatDisplayName)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white)
                                        )
                                        .padding(.trailing, 8)
                                }
                                .padding(.bottom, 0)
                            }
                        }
                    }
                    
                    // Navigation buttons (only if multiple films) - centered vertically
                    if hasMultiple {
                        HStack {
                            // Left button - previous film
                            Button(intent: PreviousFilmIntent()) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 0.5)
                                    .padding(.leading, 4)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            // Right button - next film
                            Button(intent: NextFilmIntent()) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 0.5)
                                    .padding(.trailing, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .widgetURL(hasMultiple ? nil : URL(string: "filmstock://loadedfilms"))
            } else {
                Color.gray.opacity(0.3)
                    .widgetBackground {
                        Color.gray.opacity(0.3)
                    }
                    .widgetURL(URL(string: "filmstock://loadedfilms"))
            }
        }
    }
}

struct EmptyWidgetView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 32))
                .foregroundColor(.gray)
            
            Text("widget.noFilms")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
        }
    }
}


#Preview(as: .systemSmall) {
    LoadedFilmsWidget()
} timeline: {
    LoadedFilmsWidgetEntry(
        date: Date(),
        loadedFilms: [
            LoadedFilmWidgetData(
                id: "1",
                filmName: "Portra 400",
                manufacturer: "Kodak",
                format: "120",
                camera: "Hasselblad 500CM",
                imageData: nil,
                loadedAt: Date()
            )
        ],
        currentIndex: 0,
        configuration: LoadedFilmsWidgetConfiguration()
    )
    LoadedFilmsWidgetEntry(
        date: Date(),
        loadedFilms: [],
        currentIndex: 0,
        configuration: LoadedFilmsWidgetConfiguration()
    )
}

