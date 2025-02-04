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
    
    var displayTeacher: String {
        return teacherName ?? "-"
    }
    
    var displayAuditory: String {
        return auditoryName ?? "-"
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
                    if let schedule = schedule {
                        ForEach(filteredSchedule, id: \.0.number) { item, days in
                            ForEach(days, id: \.info.date) { day in
                                ScheduleDaySection(day: day, isToday: isToday(date:))
                                    .id(day.info.date)
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
                    scrollToToday(proxy: proxy)
                }
            }
        }
    }
    
    private func scrollToToday(proxy: ScrollViewProxy) {
        if let schedule = schedule {
            for item in schedule.items {
                if let todaySection = item.days.first(where: { isToday(date: $0.info.date) }) {
                    withAnimation {
                        proxy.scrollTo(todaySection.info.date, anchor: .center)
                    }
                }
            }
        }
    }
    
    private func loadSchedule() async {
        guard let url = URL(string: "https://gg-api.ystuty.ru/s/schedule/v1/schedule/group/\(groupName)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            schedule = try decoder.decode(ScheduleResponse.self, from: data)
        } catch {
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
}

struct ScheduleDaySection: View {
    let day: DaySchedule
    let isToday: (String) -> Bool
    
    var body: some View {
        Section(day.info.formattedDate) {
            ForEach(day.lessons, id: \.self) { lesson in
                LessonRow(lesson: lesson)
            }
        }
        .listRowBackground(
            Group {
                if isToday(day.info.date) {
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

struct LessonRow: View {
    let lesson: Lesson
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(lesson.lessonName)
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
