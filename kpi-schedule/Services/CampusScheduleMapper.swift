//
//  CampusScheduleMapper.swift
//  kpi-schedule
//
//  Created by Maksym on 06.11.2026.
//

import Foundation

struct CampusScheduleMapper {
    func dtos(from data: Data, groupName: String) throws -> [LessonDTO] {
        let response = try JSONDecoder().decode(CampusScheduleResponse.self, from: data)
        let all = map(response.scheduleFirstWeek, week: "перший", group: groupName)
                + map(response.scheduleSecondWeek, week: "другий", group: groupName)
        return markElectives(all)
    }

    private func map(_ days: [CampusDay]?, week: String, group: String) -> [LessonDTO] {
        var result: [LessonDTO] = []
        var indexByKey: [String: Int] = [:]

        for day in days ?? [] {
            // "Пн", "Вт" => "Понеділок", "Вівторок"
            let dayName = Weekday(name: day.day)?.localizedName ?? day.day

            for pair in day.pairs ?? [] {
                let teacher = pair.lecturer?.name ?? ""
                let room = pair.location?.title.flatMap { $0.isEmpty ? nil : $0 }
                let dates = Array(Set((pair.dates ?? []).map(LessonDates.normalize)))

                // Один предмет у тому самому слоті API може віддати кілька разів, тому зливаємо дати
                let key = [dayName, week, pair.time ?? "", pair.name, pair.type ?? "", teacher, room ?? ""]
                    .joined(separator: "|")

                if let index = indexByKey[key] {
                    var merged = result[index]
                    let existing = merged.dates ?? []
                    // порожні дати = пара щотижня, вона перекриває «спец.» дати
                    merged.dates = (existing.isEmpty || dates.isEmpty) ? [] : Array(Set(existing).union(dates)).sorted()
                    result[index] = merged
                } else {
                    indexByKey[key] = result.count
                    result.append(LessonDTO(group: group, day: dayName, week: week,
                                            subject: pair.name, teacher: teacher,
                                            type: pair.type ?? "", time: pair.time,
                                            room: room, online: room == nil ? true : nil, link: nil, elective: nil,   // без аудиторії в API = онлайн
                                            
                                            dates: dates.sorted()))
                }
            }
        }
        return result
    }

    /// API не каже, що предмет вибірковий. Ознака: у групи в одному слоті (тиждень + день + час)
    /// є інший предмет, який може йти в ті самі дати, тобто студент обирає один із них
    private func markElectives(_ dtos: [LessonDTO]) -> [LessonDTO] {
        var slots: [String: [LessonDTO]] = [:]
        for dto in dtos {
            slots["\(dto.week ?? "")|\(dto.day)|\(dto.time ?? "")", default: []].append(dto)
        }
        var electiveSubjects: Set<String> = []
        for group in slots.values {
            for a in group {
                for b in group where a.subject != b.subject && canCoincide(a, b) {
                    electiveSubjects.insert(a.subject)
                    break
                }
            }
        }
        // Нормативний предмет має лекцію щотижня; без лекцій досить будь-якої щотижневої пари
        // Усе інше (лекції лише в окремі дати) вибіркове, навіть якщо в слоті воно саме
        for (subject, list) in Dictionary(grouping: dtos, by: \.subject) {
            let lectures = list.filter { $0.type.lowercased().hasPrefix("лек") || $0.type.lowercased().hasPrefix("lec") }
            if !(lectures.isEmpty ? list : lectures).contains(where: { ($0.dates ?? []).isEmpty }) {
                electiveSubjects.insert(subject)
            }
        }
        return dtos.map { dto in
            LessonDTO(group: dto.group, day: dto.day, week: dto.week, subject: dto.subject,
                      teacher: dto.teacher, type: dto.type, time: dto.time, room: dto.room,
                      online: dto.online, link: dto.link,
                      elective: electiveSubjects.contains(dto.subject) ? true : nil,
                      dates: dto.dates)
        }
    }

    /// Дві пари можуть іти одночасно, якщо одна з них щотижнева або в них є спільна дата
    private func canCoincide(_ a: LessonDTO, _ b: LessonDTO) -> Bool {
        let da = a.dates ?? [], db = b.dates ?? []
        return da.isEmpty || db.isEmpty || !Set(da).isDisjoint(with: db)
    }
}
