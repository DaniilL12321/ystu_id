import SwiftUI

struct ScheduleView: View {
    @State private var faculties: [FacultyItem] = []
    @State private var selectedFaculty: FacultyItem?
    @State private var selectedGroup: String?
    
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
    
    var body: some View {
        List {
            if let schedule = schedule {
                ForEach(schedule.items, id: \.number) { item in
                    ForEach(item.days, id: \.info.date) { day in
                        Section(day.info.date) {
                            ForEach(day.lessons, id: \.number) { lesson in
                                VStack(alignment: .leading) {
                                    Text(lesson.lessonName)
                                        .font(.headline)
                                    Text(lesson.timeRange)
                                    Text(lesson.auditoryName)
                                    Text(lesson.teacherName)
                                }
                            }
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(groupName)
        .task {
            await loadSchedule()
        }
    }
    
    private func loadSchedule() async {
        guard let url = URL(string: "https://gg-api.ystuty.ru/s/schedule/v1/schedule/group/\(groupName)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            schedule = try JSONDecoder().decode(ScheduleResponse.self, from: data)
        } catch {
            print("Ошибка загрузки расписания: \(error)")
        }
    }
} 