//
//  WidgetConfigurationIntent.swift
//  FilmStockWidget
//
//  Widget configuration intent
//

import AppIntents
import Foundation

struct LoadedFilmsWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "widget.config.title"
    static var description = IntentDescription("widget.config.description")
    
    @Parameter(title: "widget.config.showFilmInfo", default: false)
    var showFilmInfo: Bool?
    
    @Parameter(title: "widget.config.infoPosition", default: .top)
    var infoPosition: InfoPosition?
    
    init() {
        self.showFilmInfo = false
        self.infoPosition = .top
    }
    
    init(showFilmInfo: Bool?, infoPosition: InfoPosition?) {
        self.showFilmInfo = showFilmInfo
        self.infoPosition = infoPosition
    }
}

enum InfoPosition: String, AppEnum {
    case top
    case bottom
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.config.position"
    static var caseDisplayRepresentations: [InfoPosition: DisplayRepresentation] = [
        .top: "widget.config.position.top",
        .bottom: "widget.config.position.bottom"
    ]
}

