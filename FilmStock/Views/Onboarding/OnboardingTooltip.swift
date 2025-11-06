//
//  OnboardingTooltip.swift
//  FilmStock
//
//  Reusable tooltip component for highlighting UI elements
//

import SwiftUI

struct TooltipPreference: Equatable {
    let id: String
    let frame: CGRect
    let title: String
    let message: String
    let anchor: OnboardingTooltip.TooltipAnchor
    let isVisible: Bool
}

struct TooltipPreferenceKey: PreferenceKey {
    static var defaultValue: [TooltipPreference] = []
    
    static func reduce(value: inout [TooltipPreference], nextValue: () -> [TooltipPreference]) {
        value.append(contentsOf: nextValue())
    }
}

struct OnboardingTooltip: ViewModifier {
    let id: String
    let title: String
    let message: String
    let anchor: TooltipAnchor
    let isVisible: Bool
    let onDismiss: () -> Void
    
    enum TooltipAnchor {
        case top
        case bottom
        case leading
        case trailing
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: TooltipPreferenceKey.self, value: [
                            TooltipPreference(
                                id: id,
                                frame: geometry.frame(in: .global),
                                title: title,
                                message: message,
                                anchor: anchor,
                                isVisible: isVisible && !OnboardingManager.shared.hasSeenTooltip(id)
                            )
                        ])
                }
            )
    }
}

extension View {
    func onboardingTooltip(
        id: String,
        title: String,
        message: String,
        anchor: OnboardingTooltip.TooltipAnchor = .bottom,
        isVisible: Bool = true,
        onDismiss: @escaping () -> Void = {}
    ) -> some View {
        modifier(OnboardingTooltip(
            id: id,
            title: title,
            message: message,
            anchor: anchor,
            isVisible: isVisible,
            onDismiss: onDismiss
        ))
    }
}

