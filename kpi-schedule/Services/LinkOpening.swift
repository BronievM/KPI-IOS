//
//  LinkOpening.swift
//  kpi-schedule
//
//  Created by Maksym on 21.10.2026.
//

import UIKit

/// Абстракція відкриття посилань для зручного тестування
protocol LinkOpening {
    func open(_ url: URL)
}

struct SystemLinkOpener: LinkOpening {
    func open(_ url: URL) {
        UIApplication.shared.open(url)
    }
}
