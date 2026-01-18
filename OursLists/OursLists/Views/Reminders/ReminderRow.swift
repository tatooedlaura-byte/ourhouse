import SwiftUI

struct ReminderRow: View {
    @ObservedObject var reminder: Reminder
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showingEdit = false

    var body: some View {
        HStack(spacing: 12) {
            // Done button
            Button {
                markDone()
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(reminder.isPaused ? .gray : .green)
            }
            .buttonStyle(.plain)
            .disabled(reminder.isPaused)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title ?? "")
                    .foregroundStyle(reminder.isPaused ? .secondary : .primary)

                HStack(spacing: 8) {
                    // Due label
                    Text(reminder.dueDescription)
                        .font(.caption)
                        .foregroundStyle(reminder.isOverdue ? .red : .secondary)

                    // Notes indicator
                    if let notes = reminder.notes, !notes.isEmpty {
                        Text("• Has notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Last completed info
                if let completedInfo = reminder.lastCompletedDescription {
                    Text(completedInfo)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }

            Spacer()

            // Frequency badge
            Text(reminder.frequencyEnum.rawValue)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.1))
                .foregroundStyle(.orange)
                .cornerRadius(4)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingEdit = true
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewContext.delete(reminder)
                try? viewContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                reminder.isPaused.toggle()
                if reminder.isPaused {
                    NotificationService.shared.cancelReminderNotification(for: reminder)
                } else {
                    NotificationService.shared.scheduleReminderNotification(for: reminder)
                }
                try? viewContext.save()
            } label: {
                Label(reminder.isPaused ? "Resume" : "Pause", systemImage: reminder.isPaused ? "play" : "pause")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading) {
            Button {
                markDone()
            } label: {
                Label("Done", systemImage: "checkmark")
            }
            .tint(.green)
            .disabled(reminder.isPaused)

            Button {
                snooze()
            } label: {
                Label("Snooze", systemImage: "clock.arrow.circlepath")
            }
            .tint(.blue)
            .disabled(reminder.isPaused)
        }
        .sheet(isPresented: $showingEdit) {
            EditReminderSheet(reminder: reminder)
        }
    }

    private func markDone() {
        withAnimation {
            reminder.markDone()
            try? viewContext.save()
        }
    }

    private func snooze() {
        withAnimation {
            reminder.snooze(days: 1)
            try? viewContext.save()
        }
    }
}
