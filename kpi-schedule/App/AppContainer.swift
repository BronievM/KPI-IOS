//
//  AppContainer.swift
//  kpi-schedule
//
//  Created by Maksym on 20.10.2026.
//

import Foundation

enum AppContainer {
    static func makeScheduleViewModel() -> ScheduleViewModel {
        ScheduleViewModel(
            repository: JSONScheduleRepository(json: SampleScheduleData.json),
            linkOpener: SystemLinkOpener(),
            clock: SystemScheduleClock()
        )
    }
}

enum SampleScheduleData {
    static let json = """
    [
        { "group": "ІО-42", "day": "Monday", "week": "first", "time": "10:25", "subject": "iOS Application Development", "teacher": "Halytskiy D. V.", "type": "Lecture", "online": true },
        { "group": "ІО-42", "day": "Monday", "week": "first", "time": "12:20", "subject": "Parallel and Distributed Computing", "teacher": "Korochkin O. V.", "type": "Lecture", "online": true },
        { "group": "ІО-42", "day": "Monday", "week": "first", "time": "08:30", "subject": "Computer Graphics and Multimedia", "teacher": "Rodionov P. Y.", "type": "Lecture", "online": true },
        { "group": "ІО-42", "day": "Tuesday", "week": "first", "time": "12:20", "subject": "Parallel and Distributed Computing", "teacher": "Korochkin O. V.", "type": "Laboratory", "online": false, "room": "18-515" },
        { "group": "ІО-42", "day": "Tuesday", "week": "first", "time": "14:15", "subject": "Computer Architecture. Part 2. Processors", "teacher": "Kaplunov A. V.", "type": "Laboratory", "online": false, "room": "18-535" },
        { "group": "ІО-42", "day": "Wednesday", "week": "first", "time": "08:30", "subject": "iOS Application Development", "teacher": "Halytskiy D. V.", "type": "Lecture", "online": true, "link": "https://github.com/BronievM/KPI-IOS" },
        { "group": "ІО-42", "day": "Wednesday", "week": "first", "time": "12:20", "subject": "Computer Graphics and Image Processing", "teacher": "Shcheblanin Y. M.", "type": "Laboratory", "online": false, "room": "18-200" },
        { "group": "ІО-42", "day": "Thursday", "week": "first", "time": "08:30", "subject": "Computer Architecture. Part 2. Processors", "teacher": "Klymenko I. A.", "type": "Lecture", "online": true },
        { "group": "ІО-42", "day": "Thursday", "week": "first", "time": "12:20", "subject": "Computer Networks", "teacher": "Kulakov Y. O.", "type": "Lecture", "online": true },
        { "group": "ІО-42", "day": "Monday", "week": "second", "time": "10:25", "subject": "iOS Application Development", "teacher": "Halytskiy D. V.", "type": "Lecture", "online": true },
        { "group": "ІО-42", "day": "Tuesday", "week": "second", "time": "10:25", "subject": "Introduction to Artificial Intelligence", "teacher": "Kochura Y. P.", "type": "Laboratory", "online": false, "room": "18-538" },
        { "group": "ІО-42", "day": "Tuesday", "week": "second", "time": "12:20", "subject": "Computer Networks", "teacher": "Alenin O. I.", "type": "Laboratory", "online": false, "room": "18-516" },
        { "group": "ІО-42", "day": "Wednesday", "week": "second", "time": "08:30", "subject": "Information Support for Industrial Robots", "teacher": "Tyulyakov D. I.", "type": "Laboratory", "online": false, "room": "18-534" },
        { "group": "ІО-42", "day": "Wednesday", "week": "second", "time": "10:25", "subject": "Computer Graphics and Multimedia", "teacher": "Rodionov P. Y.", "type": "Laboratory", "online": false, "room": "18-417" },
        { "group": "ІО-42", "day": "Thursday", "week": "second", "time": "10:25", "subject": "Parallel and Distributed Computing", "teacher": "Korochkin O. V.", "type": "Lecture", "online": true },
        { "group": "ІО-42", "day": "Saturday", "week": "second", "time": "14:15", "subject": "Foreign Language for Professional Purposes", "teacher": "Doroshenko L. V.", "type": "Practical", "online": true }
    ]
    """
}

