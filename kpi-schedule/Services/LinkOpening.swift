//
//  LinkOpening.swift
//  kpi-schedule
//
//  Created by Maksym on 20.10.2026.
//

import UIKit

protocol LinkOpening {
    func open(_ url: URL)
}

struct SystemLinkOpener: LinkOpening {
    func open(_ url: URL) {
       UIApplication.shared.open(url)
    }
}
