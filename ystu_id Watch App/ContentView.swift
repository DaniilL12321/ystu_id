//
//  ContentView.swift
//  ystu_id Watch App
//
//  Created by Daniil on 04.02.2025.
//

import SwiftUI

struct GroupsResponse: Codable {
    let isCache: Bool
    let name: String
    let items: [FacultyItem]
}

struct FacultyItem: Codable {
    let name: String
    let groups: [String]
}

struct ScheduleResponse: Codable {
    let isCache: Bool
    let items: [ScheduleItem]
}

struct ScheduleItem: Codable {
    let number: Int?
    let days: [DaySchedule]
}

struct DaySchedule: Codable {
    let info: DayInfo
    let lessons: [Lesson]
}

struct DayInfo: Codable {
    let type: Int?
    let weekNumber: Int?
    let date: String
    
    var formattedDate: String {
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        guard let date = isoFormatter.date(from: date) else {
            isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            guard let date = isoFormatter.date(from: date) else {
                return "-"
            }
            return formatDate(date)
        }
        return formatDate(date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        let dateString = formatter.string(from: date)
        return dateString.prefix(1).uppercased() + dateString.dropFirst()
    }
}

struct Lesson: Codable {
    let number: Int?
    let startAt: String?
    let endAt: String?
    let timeRange: String?
    let lessonName: String
    let teacherId: Int?
    let teacherName: String?
    let auditoryName: String?
    let isDistant: Bool?
    let isLecture: Bool?
    
    enum CodingKeys: String, CodingKey {
        case number, startAt, endAt, timeRange, lessonName, teacherId, teacherName, auditoryName, isDistant, isLecture
    }
    
    init(number: Int?, startAt: String?, endAt: String?, timeRange: String?, lessonName: String, teacherId: Int?, teacherName: String?, auditoryName: String?, isDistant: Bool?, isLecture: Bool?) {
        self.number = number
        self.startAt = startAt
        self.endAt = endAt
        self.timeRange = timeRange
        self.lessonName = lessonName
        self.teacherId = teacherId
        self.teacherName = teacherName
        self.auditoryName = auditoryName
        self.isDistant = isDistant
        self.isLecture = isLecture
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.number = try? container.decodeIfPresent(Int.self, forKey: .number)
        self.startAt = try? container.decodeIfPresent(String.self, forKey: .startAt)
        self.endAt = try? container.decodeIfPresent(String.self, forKey: .endAt)
        self.timeRange = try? container.decodeIfPresent(String.self, forKey: .timeRange)
        self.teacherId = try? container.decodeIfPresent(Int.self, forKey: .teacherId)
        self.teacherName = try? container.decodeIfPresent(String.self, forKey: .teacherName)
        self.auditoryName = try? container.decodeIfPresent(String.self, forKey: .auditoryName)
        self.isDistant = try? container.decodeIfPresent(Bool.self, forKey: .isDistant)
        self.isLecture = try? container.decodeIfPresent(Bool.self, forKey: .isLecture)
        
        if let single = try? container.decodeIfPresent(String.self, forKey: .lessonName) {
            self.lessonName = single
        } else if let multiple = try? container.decodeIfPresent([String].self, forKey: .lessonName) {
            self.lessonName = multiple.joined(separator: ", ")
        } else {
            self.lessonName = "Предмет без названия"
        }
    }
    
    var displayTeacher: String {
        return teacherName ?? "Препод не указан"
    }
    
    var displayAuditory: String {
        let trimmed = auditoryName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == nil || trimmed == "" {
            return isDistantLesson ? "Дистант" : "Аудитории нет"
        }
        return trimmed!
    }
    
    var displayTime: String {
        return timeRange ?? "-"
    }
    
    var isDistantLesson: Bool {
        return isDistant ?? false
    }
    
    var isLectureLesson: Bool {
        return isLecture ?? false
    }
}

struct ContentView: View {
    @AppStorage("selectedGroup") private var savedGroup: String?
    
    var body: some View {
        if let group = savedGroup {
            GroupScheduleView(groupName: group)
        } else {
            ScheduleView()
        }
    }
}

struct ScheduleView: View {
    @State private var faculties: [FacultyItem] = []
    @State private var selectedFaculty: FacultyItem?
    @State private var selectedGroup: String?
    @AppStorage("selectedGroup") private var savedGroup: String?
    
    var body: some View {
        NavigationView {
            List {
                if selectedFaculty == nil {
                    ForEach(faculties, id: \.name) { faculty in
                        Button(faculty.name) {
                            selectedFaculty = faculty
                        }
                    }
                } else if let faculty = selectedFaculty {
                    Button("Назад") {
                        selectedFaculty = nil
                    }
                    ForEach(faculty.groups, id: \.self) { group in
                        NavigationLink(group) {
                            GroupScheduleView(groupName: group)
                                .onAppear {
                                    savedGroup = group
                                }
                        }
                    }
                }
            }
            .navigationTitle("Расписание")
            .task {
                await loadGroups()
            }
        }
    }
    
    private func loadGroups() async {
        guard let url = URL(string: "https://gg-api.ystuty.ru/s/schedule/v1/schedule/actual_groups") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GroupsResponse.self, from: data)
            faculties = response.items
        } catch {
            print("Ошибка загрузки групп: \(error)")
        }
    }
}

struct GroupScheduleView: View {
    let groupName: String
    @State private var schedule: ScheduleResponse?
    @State private var currentDayId: String?
    @AppStorage("selectedGroup") private var savedGroup: String?
    @Environment(\.dismiss) private var dismiss
    @State private var renderStart: Date?
    @State private var renderLogged: Bool = false
    @State private var allDays: [DaySchedule] = []
    @State private var visibleStart: Int = 0
    @State private var visibleEnd: Int = 0
    @State private var dateTitleById: [String: String] = [:]

    private var visibleDays: [DaySchedule] {
        guard allDays.indices.contains(visibleStart), visibleEnd >= visibleStart, visibleEnd <= allDays.count else { return [] }
        return Array(allDays[visibleStart..<visibleEnd])
    }
    
    var filteredSchedule: [(ScheduleItem, [DaySchedule])] {
        guard let schedule = schedule else { return [] }
        
        return schedule.items.map { item in
            let filteredDays = item.days.filter { day in
                isInCurrentSemester(date: day.info.date)
            }
            return (item, filteredDays)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    if let _ = schedule {
                        RenderReporter {
                            reportRenderTime()
                        }
                        if visibleStart > 0 {
                            Section("") {
                                Button("Показать предыдущие") {
                                    expandTop()
                                }
                            }
                        }
                        ForEach(visibleDays, id: \.info.date) { day in
                            if shouldInsertNoClassesBanner(before: day.info.date) {
                                NoClassesTodaySection()
                            }
                            ScheduleDaySection(title: dateTitleById[day.info.date] ?? day.info.formattedDate, day: day, shouldHighlight: { shouldHighlight($0) })
                                .id(day.info.date)
                        }
                        if visibleEnd < allDays.count {
                            Section("") {
                                Button("Показать ещё") {
                                    expandBottom()
                                }
                            }
                        }
                    } else {
                        ProgressView()
                    }
                }
                .navigationTitle(groupName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            savedGroup = nil
                        } label: {
                            Image(systemName: "chevron.left")
                            Text("Назад")
                        }
                    }
                }
                .task {
                    await loadSchedule()
                }
                .onChange(of: schedule) { _ in
                    scrollToInitialAnchor(proxy: proxy)
                }
            }
        }
    }
    
    private func scrollToInitialAnchor(proxy: ScrollViewProxy) {
        if let anchor = highlightedDayId() {
            withAnimation {
                proxy.scrollTo(anchor, anchor: .center)
            }
        }
    }
    
    private func loadSchedule() async {
        guard let baseURL = URL(string: "https://gg-api.ystuty.ru/s/schedule/v1/schedule/group") else { return }
        let url = baseURL.appendingPathComponent(groupName)
        
        do {
            let start = Date()
            let (data, _) = try await URLSession.shared.data(from: url)
            let netMs = Int(Date().timeIntervalSince(start) * 1000)
            print("[ScheduleTiming] Network: \(netMs) ms (\(groupName))")
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            let decodeStart = Date()
            let decoded = try decoder.decode(ScheduleResponse.self, from: data)
            let decodeMs = Int(Date().timeIntervalSince(decodeStart) * 1000)
            schedule = decoded
            let totalMs = Int(Date().timeIntervalSince(start) * 1000)
            print("[ScheduleTiming] Decode: \(decodeMs) ms; Total to state: \(totalMs) ms (\(groupName))")
            renderStart = Date()
            renderLogged = false
            prepareVisibleDays()
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                return
            }
            print("Ошибка загрузки расписания: \(error)")
            
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("Не найден ключ: \(key.stringValue)")
                    print("Путь: \(context.codingPath.map { $0.stringValue })")
                case .typeMismatch(let type, let context):
                    print("Несоответствие типа: ожидался \(type)")
                    print("Путь: \(context.codingPath.map { $0.stringValue })")
                default:
                    print("Другая ошибка декодирования: \(decodingError)")
                }
            }
        }
    }

    private func prepareVisibleDays() {
        guard let schedule = schedule else {
            allDays = []
            visibleStart = 0
            visibleEnd = 0
            dateTitleById = [:]
            return
        }
        var days: [DaySchedule] = []
        for item in schedule.items {
            for day in item.days {
                if isInCurrentSemester(date: day.info.date) {
                    days.append(day)
                }
            }
        }
        days.sort { a, b in
            guard let da = parseDate(a.info.date), let db = parseDate(b.info.date) else { return a.info.date < b.info.date }
            return da < db
        }
        allDays = days
        var titles: [String: String] = [:]
        for d in days {
            titles[d.info.date] = d.info.formattedDate
        }
        dateTitleById = titles
        let anchorId = highlightedDayId()
        let anchorIndex = anchorId.flatMap { id in days.firstIndex(where: { $0.info.date == id }) } ?? 0
        let start = max(0, anchorIndex - 3)
        let end = min(days.count, anchorIndex + 7)
        visibleStart = start
        visibleEnd = end
    }

    private func expandTop(step: Int = 10) {
        guard !allDays.isEmpty else { return }
        let newStart = max(0, visibleStart - step)
        visibleStart = newStart
    }

    private func expandBottom(step: Int = 10) {
        guard !allDays.isEmpty else { return }
        let newEnd = min(allDays.count, visibleEnd + step)
        visibleEnd = newEnd
    }

    private func reportRenderTime() {
        guard let renderStart = renderStart, !renderLogged else { return }
        let ms = Int(Date().timeIntervalSince(renderStart) * 1000)
        print("[ScheduleTiming] Render: \(ms) ms after state (\(groupName))")
        renderLogged = true
    }
    
    private func isInCurrentSemester(date: String) -> Bool {
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        guard let lessonDate = isoFormatter.date(from: date) else {
            isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            guard let lessonDate = isoFormatter.date(from: date) else {
                return false
            }
            return isDateInCurrentSemester(lessonDate)
        }
        return isDateInCurrentSemester(lessonDate)
    }
    
    private func isDateInCurrentSemester(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let currentDate = Date()
        
        let currentMonth = calendar.component(.month, from: currentDate)
        let lessonMonth = calendar.component(.month, from: date)
        
        if currentMonth >= 9 && currentMonth <= 12 {
            return lessonMonth >= 9 && lessonMonth <= 12
        } else {
            return lessonMonth >= 1 && lessonMonth <= 8
        }
    }
    
    private func isToday(date: String) -> Bool {
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        guard let lessonDate = isoFormatter.date(from: date) else {
            isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            guard let lessonDate = isoFormatter.date(from: date) else {
                return false
            }
            return Calendar.current.isDateInToday(lessonDate)
        }
        return Calendar.current.isDateInToday(lessonDate)
    }

    private func parseDate(_ date: String) -> Date? {
        let f1 = DateFormatter()
        f1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let d = f1.date(from: date) { return d }
        let f2 = DateFormatter()
        f2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return f2.date(from: date)
    }

    private func todayDayId() -> String? {
        guard let schedule = schedule else { return nil }
        for item in schedule.items {
            if let today = item.days.first(where: { isToday(date: $0.info.date) }) {
                return today.info.date
            }
        }
        return nil
    }

    private func nextAvailableDayId() -> String? {
        guard let schedule = schedule else { return nil }
        let now = Date()
        var next: (date: Date, id: String)? = nil
        for item in schedule.items {
            for day in item.days {
                guard let d = parseDate(day.info.date) else { continue }
                if d >= now && !day.lessons.isEmpty {
                    if let cur = next {
                        if d < cur.date { next = (d, day.info.date) }
                    } else {
                        next = (d, day.info.date)
                    }
                }
            }
        }
        return next?.id
    }

    private func highlightedDayId() -> String? {
        if let today = todayDayId() { return today }
        return nextAvailableDayId()
    }

    private func shouldHighlight(_ dateId: String) -> Bool {
        if let today = todayDayId() { return today == dateId }
        if let next = nextAvailableDayId() { return next == dateId }
        return false
    }

    private func shouldInsertNoClassesBanner(before dateId: String) -> Bool {
        return todayDayId() == nil && nextAvailableDayId() == dateId
    }
}

struct ScheduleDaySection: View {
    let title: String
    let day: DaySchedule
    let shouldHighlight: (String) -> Bool
    
    var body: some View {
        Section(title) {
            ForEach(day.lessons, id: \.self) { lesson in
                LessonRow(lesson: lesson)
            }
        }
        .listRowBackground(
            Group {
                if shouldHighlight(day.info.date) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.blue, lineWidth: 2)
                        )
                } else {
                    Color.clear
                }
            }
        )
    }
}

struct NoClassesTodaySection: View {
    var body: some View {
        Section("Сегодня — пар нет") {
            HStack {
                Image(systemName: "moon.zzz.fill")
                Text("Отдыхаем")
            }
        }
    }
}

struct RenderReporter: View {
    let onFirstAppear: () -> Void
    @State private var appeared = false
    var body: some View {
        Color.clear
            .frame(height: 0.1)
            .onAppear {
                if !appeared {
                    appeared = true
                    onFirstAppear()
                }
            }
    }
}

struct LessonRow: View {
    let lesson: Lesson
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(lesson.lessonName.isEmpty ? "Предмет без названия" : lesson.lessonName)
                .font(.headline)
            Text(lesson.displayTime)
            Text(lesson.displayAuditory)
            Text(lesson.displayTeacher)
        }
    }
}

extension ScheduleItem: Hashable, Equatable {
    static func == (lhs: ScheduleItem, rhs: ScheduleItem) -> Bool {
        lhs.number == rhs.number && lhs.days == rhs.days
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }
}

extension Lesson: Hashable, Equatable {
    static func == (lhs: Lesson, rhs: Lesson) -> Bool {
        lhs.number == rhs.number &&
        lhs.startAt == rhs.startAt &&
        lhs.endAt == rhs.endAt &&
        lhs.timeRange == rhs.timeRange &&
        lhs.lessonName == rhs.lessonName &&
        lhs.teacherId == rhs.teacherId &&
        lhs.teacherName == rhs.teacherName &&
        lhs.auditoryName == rhs.auditoryName &&
        lhs.isDistant == rhs.isDistant &&
        lhs.isLecture == rhs.isLecture
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
        hasher.combine(startAt)
        hasher.combine(lessonName)
    }
}

extension ScheduleResponse: Equatable {
    static func == (lhs: ScheduleResponse, rhs: ScheduleResponse) -> Bool {
        lhs.isCache == rhs.isCache && lhs.items == rhs.items
    }
}

extension DaySchedule: Equatable {
    static func == (lhs: DaySchedule, rhs: DaySchedule) -> Bool {
        lhs.info == rhs.info && lhs.lessons == rhs.lessons
    }
}

extension DayInfo: Equatable {
    static func == (lhs: DayInfo, rhs: DayInfo) -> Bool {
        lhs.type == rhs.type &&
        lhs.weekNumber == rhs.weekNumber &&
        lhs.date == rhs.date
    }
}

#Preview {
    ContentView()
}
