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
    let customFormatName: String?
    let camera: String
    let imageData: Data?
    let loadedAt: Date?
    let effectiveISO: Int
    
    var formatDisplayName: String {
        // Use custom format name if available
        if let customName = customFormatName, !customName.isEmpty {
            return customName
        }
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
    
    var isoDisplayString: String {
        return "ISO \(effectiveISO)"
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
            let filmIndex = max(0, min(entry.currentIndex, entry.loadedFilms.count - 1))
            let film = entry.loadedFilms[filmIndex]
            let hasMultiple = entry.loadedFilms.count > 1
            let resolvedImage = film.imageData.flatMap { UIImage(data: $0) }
            
            ZStack {
                Color.clear
                    .widgetBackground {
                        if let uiImage = resolvedImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            noImageBackground(for: film, hasMultiple: hasMultiple)
                        }
                    }
                
                if entry.configuration.showFilmInfo ?? false {
                    VStack {
                        if (entry.configuration.infoPosition ?? .top) == .top {
                            filmInfoBar(for: film)
                        }
                        Spacer()
                        if (entry.configuration.infoPosition ?? .top) == .bottom {
                            filmInfoBar(for: film)
                        }
                    }
                }
                
                if hasMultiple {
                    HStack {
                        Button(intent: PreviousFilmIntent()) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                                .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 0.5)
                                .frame(width: 28, height: 44, alignment: .leading)
                                .padding(.leading, 4)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button(intent: NextFilmIntent()) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                                .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 0.5)
                                .frame(width: 28, height: 44, alignment: .trailing)
                                .padding(.trailing, 4)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .widgetURL(widgetURL(for: film))
        }
    }
    
    @ViewBuilder
    private func filmInfoBar(for film: LoadedFilmWidgetData) -> some View {
        HStack(spacing: 4) {
            if !film.camera.isEmpty {
                Text(film.camera)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .padding(.leading, 8)
            }
            
            Spacer(minLength: 4)
            
            Text(film.isoDisplayString)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .fixedSize()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                )
                .padding(.trailing, 8)
        }
    }
    
    @ViewBuilder
    private func noImageBackground(for film: LoadedFilmWidgetData, hasMultiple: Bool) -> some View {
        ZStack {
            Color(white: 0.16)
            VStack(spacing: 4) {
                if !film.manufacturer.isEmpty {
                    Text(film.manufacturer.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                }
                Text(film.filmName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text(film.formatDisplayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
            }
            .padding(.horizontal, hasMultiple ? 26 : 12)
        }
    }
    
    private func widgetURL(for film: LoadedFilmWidgetData) -> URL? {
        var components = URLComponents()
        components.scheme = "filmstock"
        components.host = "loadedfilms"
        components.queryItems = [URLQueryItem(name: "id", value: film.id)]
        return components.url
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
                customFormatName: nil,
                camera: "Hasselblad 500CM",
                imageData: nil,
                loadedAt: Date(),
                effectiveISO: 400
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

