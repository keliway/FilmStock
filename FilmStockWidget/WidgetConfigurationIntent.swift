//
//  WidgetConfigurationIntent.swift
//  FilmStockWidget
//
//  Widget configuration intent
//

import AppIntents
import Foundation

struct LoadedFilmsWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Loaded Films Widget Configuration"
    static var description = IntentDescription("Configure the loaded films widget display")
    
    @Parameter(title: "Show Film Info", default: false)
    var showFilmInfo: Bool?
    
    @Parameter(title: "Info Position", default: .top)
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
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Position"
    static var caseDisplayRepresentations: [InfoPosition: DisplayRepresentation] = [
        .top: "Top",
        .bottom: "Bottom"
    ]
}

