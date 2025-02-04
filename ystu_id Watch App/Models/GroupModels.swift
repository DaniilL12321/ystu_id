import Foundation

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
    let number: Int
    let days: [DaySchedule]
}

struct DaySchedule: Codable {
    let info: DayInfo
    let lessons: [Lesson]
}

struct DayInfo: Codable {
    let type: Int
    let weekNumber: Int
    let date: String
}

struct Lesson: Codable {
    let number: Int
    let startAt: String
    let endAt: String
    let timeRange: String
    let lessonName: String
    let teacherName: String
    let auditoryName: String
    let isDistant: Bool
    let isLecture: Bool
} 