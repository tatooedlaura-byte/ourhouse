import Foundation
import UserNotifications

class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    // Notification identifier prefixes
    private static let chorePrefix = "chore-"
    private static let taskPrefix = "task-"
    private static let reminderPrefix = "reminder-"

    init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
                self.authorizationStatus = granted ? .authorized : .denied
            }
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Chore Notifications

    func scheduleChoreNotification(for chore: ChoreModel) {
        guard let choreId = chore.id,
              let dueDate = chore.nextDueAt,
              !chore.isPaused else {
            return
        }

        cancelNotification(for: choreId, prefix: Self.chorePrefix)

        guard dueDate > Date() else { return }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Task Due Today"
        content.body = chore.title
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"
        content.userInfo = ["choreId": choreId]

        let request = UNNotificationRequest(
            identifier: "\(Self.chorePrefix)\(choreId)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Error scheduling task notification: \(error)")
            }
        }
    }

    // MARK: - Project Task Notifications

    func scheduleTaskNotification(for task: ProjectTaskModel, projectName: String? = nil) {
        guard let taskId = task.id,
              let dueDate = task.dueDate,
              task.completedAt == nil else {
            return
        }

        cancelNotification(for: taskId, prefix: Self.taskPrefix)

        guard dueDate > Date() else { return }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Project Task Due Today"
        content.body = task.title
        if let projectName = projectName {
            content.subtitle = projectName
        }
        content.sound = .default
        content.categoryIdentifier = "PROJECT_TASK_REMINDER"
        content.userInfo = ["taskId": taskId]

        let request = UNNotificationRequest(
            identifier: "\(Self.taskPrefix)\(taskId)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Error scheduling project task notification: \(error)")
            }
        }
    }

    // MARK: - Reminder Notifications

    func scheduleReminderNotification(for reminder: ReminderModel) {
        guard let reminderId = reminder.id,
              let dueDate = reminder.nextDueAt,
              !reminder.isPaused else {
            return
        }

        cancelNotification(for: reminderId, prefix: Self.reminderPrefix)

        guard dueDate > Date() else { return }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Reminder Due Today"
        content.body = reminder.title
        content.sound = .default
        content.categoryIdentifier = "REMINDER"
        content.userInfo = ["reminderId": reminderId]

        let request = UNNotificationRequest(
            identifier: "\(Self.reminderPrefix)\(reminderId)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Error scheduling reminder notification: \(error)")
            }
        }
    }

    // MARK: - Cancel Notifications

    func cancelNotification(for id: String, prefix: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["\(prefix)\(id)"])
    }

    func cancelChoreNotification(for chore: ChoreModel) {
        guard let choreId = chore.id else { return }
        cancelNotification(for: choreId, prefix: Self.chorePrefix)
    }

    func cancelTaskNotification(for task: ProjectTaskModel) {
        guard let taskId = task.id else { return }
        cancelNotification(for: taskId, prefix: Self.taskPrefix)
    }

    func cancelReminderNotification(for reminder: ReminderModel) {
        guard let reminderId = reminder.id else { return }
        cancelNotification(for: reminderId, prefix: Self.reminderPrefix)
    }

    // MARK: - Reschedule All

    func rescheduleAllNotifications(chores: [ChoreModel], tasks: [ProjectTaskModel], reminders: [ReminderModel]) {
        center.removeAllPendingNotificationRequests()

        for chore in chores where !chore.isPaused {
            scheduleChoreNotification(for: chore)
        }

        for task in tasks where task.completedAt == nil && task.dueDate != nil {
            scheduleTaskNotification(for: task)
        }

        for reminder in reminders where !reminder.isPaused {
            scheduleReminderNotification(for: reminder)
        }
    }
}
