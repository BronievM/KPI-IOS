//
//  ProgressBarView.swift
//  kpi-schedule
//
//  Created by Maksym on 25.10.2026.
//

import SwiftUI

/// Анімований прогрес-бар з підтримкою Reduce Motion
struct ProgressBarView: View {
    let progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(progress >= 1 ? Color.green : Color.accentColor)
                    .frame(width: max(0, min(1, progress)) * proxy.size.width)
            }
        }
        .frame(height: 8)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8), value: progress)
        .accessibilityElement()
        .accessibilityLabel("Прогрес")
        .accessibilityValue("\(Int(progress * 100)) відсотків")
    }
}
