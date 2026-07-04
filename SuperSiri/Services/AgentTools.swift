import Foundation
import EventKit

/// A device capability the AI can invoke via tool use.
protocol AgentTool {
    var name: String { get }
    var description: String { get }
    /// JSON Schema for the tool's input (`input_schema` in the Messages API).
    var inputSchema: [String: Any] { get }
    /// Human-readable status shown in the UI while the tool runs.
    var statusLabel: String { get }
    func execute(input: [String: Any]) async throws -> String
}

enum AgentToolbox {
    /// All device tools SuperSiri exposes to the model in agent mode.
    static func allTools() -> [any AgentTool] {
        [
            ListCalendarEventsTool(),
            CreateCalendarEventTool(),
            ListRemindersTool(),
            CreateReminderTool(),
            RememberFactTool(),
        ]
    }
}

// MARK: - Shared EventKit helpers

enum EventKitAccess {
    static let store = EKEventStore()

    static func ensureCalendarAccess() async throws {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        guard granted else {
            throw AIServiceError.toolFailed(name: "Calendar", reason: "Calendar access was not granted. Enable it in iOS Settings → SuperSiri.")
        }
    }

    static func ensureReminderAccess() async throws {
        let granted = (try? await store.requestFullAccessToReminders()) ?? false
        guard granted else {
            throw AIServiceError.toolFailed(name: "Reminders", reason: "Reminders access was not granted. Enable it in iOS Settings → SuperSiri.")
        }
    }

    static func parseDate(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: string) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }
        // Fall back to "yyyy-MM-dd HH:mm" and "yyyy-MM-dd" in the local timezone.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = formatter.date(from: string) { return date }
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    static func format(_ date: Date?) -> String {
        guard let date else { return "unspecified" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - Calendar

struct ListCalendarEventsTool: AgentTool {
    let name = "list_calendar_events"
    let description = "List the user's calendar events between now and a number of days ahead. Use this before scheduling to check availability, or when the user asks about their schedule."
    let statusLabel = "Checking your calendar…"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "days_ahead": [
                    "type": "integer",
                    "description": "How many days ahead to look (1-30). Default 7.",
                ],
            ],
            "required": [],
        ]
    }

    func execute(input: [String: Any]) async throws -> String {
        try await EventKitAccess.ensureCalendarAccess()
        let days = min(max((input["days_ahead"] as? Int) ?? 7, 1), 30)
        let store = EventKitAccess.store
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: days, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        guard !events.isEmpty else {
            return "No events in the next \(days) day(s)."
        }
        let lines = events.prefix(50).map { event in
            "- \(event.title ?? "Untitled"): \(EventKitAccess.format(event.startDate)) – \(EventKitAccess.format(event.endDate))\(event.isAllDay ? " (all day)" : "")"
        }
        return "Events in the next \(days) day(s):\n" + lines.joined(separator: "\n")
    }
}

struct CreateCalendarEventTool: AgentTool {
    let name = "create_calendar_event"
    let description = "Create an event in the user's default calendar. Dates must be ISO 8601 (e.g. 2026-07-05T14:00:00Z) or 'yyyy-MM-dd HH:mm' in the user's local time."
    let statusLabel = "Adding to your calendar…"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "title": ["type": "string", "description": "Event title"],
                "start": ["type": "string", "description": "Start date-time"],
                "end": ["type": "string", "description": "End date-time. Defaults to one hour after start."],
                "notes": ["type": "string", "description": "Optional notes"],
                "all_day": ["type": "boolean", "description": "Whether this is an all-day event. Default false."],
            ],
            "required": ["title", "start"],
        ]
    }

    func execute(input: [String: Any]) async throws -> String {
        try await EventKitAccess.ensureCalendarAccess()
        guard let title = input["title"] as? String,
              let start = EventKitAccess.parseDate(input["start"] as? String)
        else {
            throw AIServiceError.toolFailed(name: "Calendar", reason: "Missing or unparseable title/start.")
        }

        let store = EventKitAccess.store
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = EventKitAccess.parseDate(input["end"] as? String) ?? start.addingTimeInterval(3600)
        event.notes = input["notes"] as? String
        event.isAllDay = (input["all_day"] as? Bool) ?? false
        event.calendar = store.defaultCalendarForNewEvents

        try store.save(event, span: .thisEvent)
        return "Created event \"\(title)\" on \(EventKitAccess.format(event.startDate))."
    }
}

// MARK: - Reminders

struct ListRemindersTool: AgentTool {
    let name = "list_reminders"
    let description = "List the user's incomplete reminders."
    let statusLabel = "Checking your reminders…"

    var inputSchema: [String: Any] {
        ["type": "object", "properties": [:], "required": []]
    }

    func execute(input: [String: Any]) async throws -> String {
        try await EventKitAccess.ensureReminderAccess()
        let store = EventKitAccess.store
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)

        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        guard !reminders.isEmpty else { return "No incomplete reminders." }
        let lines = reminders.prefix(50).map { reminder -> String in
            var line = "- \(reminder.title ?? "Untitled")"
            if let components = reminder.dueDateComponents, let due = Calendar.current.date(from: components) {
                line += " (due \(EventKitAccess.format(due)))"
            }
            return line
        }
        return "Incomplete reminders:\n" + lines.joined(separator: "\n")
    }
}

struct CreateReminderTool: AgentTool {
    let name = "create_reminder"
    let description = "Create a reminder for the user. Due date must be ISO 8601 or 'yyyy-MM-dd HH:mm' local time; omit it for an undated reminder."
    let statusLabel = "Creating a reminder…"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "title": ["type": "string", "description": "What to remind the user about"],
                "due": ["type": "string", "description": "Optional due date-time"],
                "notes": ["type": "string", "description": "Optional notes"],
            ],
            "required": ["title"],
        ]
    }

    func execute(input: [String: Any]) async throws -> String {
        try await EventKitAccess.ensureReminderAccess()
        guard let title = input["title"] as? String else {
            throw AIServiceError.toolFailed(name: "Reminders", reason: "Missing title.")
        }

        let store = EventKitAccess.store
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.notes = input["notes"] as? String
        reminder.calendar = store.defaultCalendarForNewReminders()

        var confirmation = "Created reminder \"\(title)\""
        if let due = EventKitAccess.parseDate(input["due"] as? String) {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: due
            )
            reminder.addAlarm(EKAlarm(absoluteDate: due))
            confirmation += " due \(EventKitAccess.format(due))"
        }

        try store.save(reminder, commit: true)
        return confirmation + "."
    }
}

// MARK: - Memory

struct RememberFactTool: AgentTool {
    let name = "remember"
    let description = "Save a short fact about the user to long-term memory so future conversations can use it (preferences, names, recurring context). Use only for durable facts, not one-off details."
    let statusLabel = "Saving to memory…"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "fact": ["type": "string", "description": "One-sentence fact to remember, phrased in third person (e.g. \"User prefers metric units\")."],
            ],
            "required": ["fact"],
        ]
    }

    func execute(input: [String: Any]) async throws -> String {
        guard let fact = input["fact"] as? String, !fact.isEmpty else {
            throw AIServiceError.toolFailed(name: "Memory", reason: "Missing fact.")
        }
        MemoryStore.shared.add(fact)
        return "Remembered: \(fact)"
    }
}
