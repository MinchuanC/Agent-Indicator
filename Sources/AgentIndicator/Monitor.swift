import Foundation
import Combine

@MainActor
final class Monitor: ObservableObject {
    @Published var chats: [ChatState] = []
    @Published var connection = "Connecting"
    @Published var issue: String? = "Approval prompts are not exposed reliably by local Codex records."
    @Published var lastEvent: Date?
    var onAttention: ((ChatState, String) -> Void)?
    private let queue = DispatchQueue(label: "AgentIndicator.sessionReader", qos: .utility)
    private let reader = SessionReader()
    private var timer: Timer?
    private var active = false
    func start() {
        guard !active else { return }
        active = true
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    func stop() { active = false; timer?.invalidate(); timer = nil }
    func markRead(_ id: String) {
        let reader = reader
        queue.async { [weak self] in
            reader.reducer.markRead(id)
            let snapshot = reader.snapshot()
            DispatchQueue.main.async { self?.publish(snapshot) }
        }
    }
    func refresh() {
        let reader = reader
        queue.async { [weak self] in
            let snapshot = reader.poll()
            DispatchQueue.main.async { self?.publish(snapshot) }
        }
    }
    private func publish(_ snapshot: MonitorSnapshot) {
        guard active else { return }
        chats = snapshot.chats
        connection = snapshot.connection
        issue = snapshot.issue
        lastEvent = snapshot.lastEvent
        for (chat, id) in snapshot.notices { onAttention?(chat, id) }
    }
}

private struct MonitorSnapshot {
    var chats: [ChatState]
    var connection: String
    var issue: String?
    var lastEvent: Date?
    var notices: [(ChatState, String)] = []
}

private struct FileCursor {
    let id: String
    var offset: UInt64
    var partial = Data()
    var turnID = ""
}

private final class SessionReader {
    var reducer = ChatReducer()
    private let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")
    private var cursors: [URL: FileCursor] = [:]
    private var excluded: Set<URL> = []
    private var titles: [String: String] = [:]
    private var indexModified: Date?
    private var lastDiscovery = Date.distantPast
    private var lastEvent: Date?
    private var failure: String?
    private var notices: [(ChatState, String)] = []
    private let iso = ISO8601DateFormatter()
    private let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    func snapshot() -> MonitorSnapshot {
        let chats = reducer.chats.values.sorted {
            if $0.status.priority != $1.status.priority { return $0.status.priority > $1.status.priority }
            return $0.updatedAt > $1.updatedAt
        }
        return MonitorSnapshot(chats: chats,
            connection: failure == nil ? "Monitoring \(chats.count) chats" : "Status unavailable",
            issue: failure ?? "Approval coverage is partial. Questions and turn completion are monitored; approval prompts may be missed. Local desktop chats active in the last three days are discovered automatically.",
            lastEvent: lastEvent, notices: notices)
    }
    func poll() -> MonitorSnapshot {
        notices = []
        failure = nil
        guard FileManager.default.isReadableFile(atPath: root.path) else {
            failure = "Cannot read ~/.codex/sessions. Open Codex to create local sessions, or check folder access."
            return snapshot()
        }
        loadTitles()
        discover()
        for url in Array(cursors.keys) { read(url) }
        return snapshot()
    }
    private func date(_ value: Any?) -> Date? {
        guard let value = value as? String else { return nil }
        return isoFractional.date(from: value) ?? iso.date(from: value)
    }
    private func loadTitles() {
        let url = root.deletingLastPathComponent().appendingPathComponent("session_index.jsonl")
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date, modified != indexModified,
              let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        indexModified = modified
        let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
        let start = size > 2_097_152 ? size - 2_097_152 : 0
        try? handle.seek(toOffset: start)
        guard var data = try? handle.readToEnd() else { return }
        if start > 0, let newline = data.firstIndex(of: 10) { data = data.suffix(from: data.index(after: newline)) }
        for line in data.split(separator: 10) {
            guard let row = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let id = row["id"] as? String, let title = row["thread_name"] as? String else { continue }
            titles[id] = title
            if reducer.chats[id] != nil { reducer.chats[id]?.title = title }
        }
    }
    private func discover() {
        let now = Date()
        guard now.timeIntervalSince(lastDiscovery) >= 15 else { return }
        lastDiscovery = now
        let cutoff = now.addingTimeInterval(-3 * 24 * 60 * 60)
        guard let files = FileManager.default.enumerator(at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]) else {
            failure = "Cannot discover local Codex sessions. Check folder access."
            return
        }
        for case let url as URL in files where url.pathExtension == "jsonl" && cursors[url] == nil && !excluded.contains(url) {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  values.isRegularFile == true, let modified = values.contentModificationDate,
                  modified >= cutoff else { continue }
            bootstrap(url)
        }
    }
    private func bootstrap(_ url: URL) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { failure = "A session file cannot be read."; return }
        defer { try? handle.close() }
        guard let prefix = try? handle.read(upToCount: 524_288), let line = prefix.split(separator: 10).first,
              let record = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
              record["type"] as? String == "session_meta", let meta = record["payload"] as? [String: Any],
              let id = meta["id"] as? String else { excluded.insert(url); return }
        // Read ONLY the first metadata record: child histories may replay their parent's metadata later.
        guard (meta["originator"] as? String)?.localizedCaseInsensitiveContains("desktop") == true,
              meta["parent_thread_id"] == nil, !(meta["source"] is [String: Any]) else { excluded.insert(url); return }
        let cwd = meta["cwd"] as? String ?? ""
        let project = URL(fileURLWithPath: cwd).lastPathComponent
        if reducer.chats[id] == nil {
            reducer.chats[id] = ChatState(id: id, title: titles[id] ?? (project.isEmpty ? "Codex chat" : project), project: project)
        }
        let size = (try? handle.seekToEnd()) ?? 0
        let start: UInt64 = size > 4_194_304 ? size - 4_194_304 : 0
        try? handle.seek(toOffset: start)
        guard var data = try? handle.readToEnd() else { failure = "A session file cannot be read."; return }
        if start > 0, let newline = data.firstIndex(of: 10) { data = Data(data.suffix(from: data.index(after: newline))) }
        var cursor = FileCursor(id: id, offset: size)
        consume(data, cursor: &cursor, historical: true)
        cursors[url] = cursor
    }
    private func read(_ url: URL) {
        guard var cursor = cursors[url] else { return }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = (attrs[.size] as? NSNumber)?.uint64Value else {
            let archived = root.deletingLastPathComponent().appendingPathComponent("archived_sessions").appendingPathComponent(url.lastPathComponent)
            if FileManager.default.fileExists(atPath: archived.path) {
                cursors.removeValue(forKey: url)
                reducer.chats.removeValue(forKey: cursor.id)
            } else {
                reducer.chats[cursor.id]?.status = .unavailable
                failure = "A monitored session disappeared. Refresh after Codex reconnects."
            }
            return
        }
        guard size >= cursor.offset else {
            cursors.removeValue(forKey: url)
            reducer.chats.removeValue(forKey: cursor.id)
            bootstrap(url)
            return
        }
        guard size > cursor.offset else { return }
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            try handle.seek(toOffset: cursor.offset)
            // Bound each pass while preserving the offset for the next poll.
            let data = try handle.read(upToCount: 4_194_304) ?? Data()
            cursor.offset += UInt64(data.count)
            consume(data, cursor: &cursor, historical: false)
            cursors[url] = cursor
        } catch { failure = "Cannot read a monitored session. Check folder access." }
    }
    private func consume(_ data: Data, cursor: inout FileCursor, historical: Bool) {
        cursor.partial.append(data)
        while let newline = cursor.partial.firstIndex(of: 10) {
            let line = Data(cursor.partial.prefix(upTo: newline))
            cursor.partial.removeSubrange(...newline)
            parse(line, cursor: &cursor, historical: historical)
        }
        if cursor.partial.count > 8_388_608 {
            cursor.partial.removeAll()
            failure = "A Codex record exceeds the supported size. Status may be incomplete."
        }
    }
    private func parse(_ line: Data, cursor: inout FileCursor, historical: Bool) {
        guard let record = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let payload = record["payload"] as? [String: Any] else { return }
        let time = date(record["timestamp"]) ?? Date()
        let recordType = record["type"] as? String ?? ""
        let type = payload["type"] as? String ?? ""
        func emit(_ kind: ChatEvent.Kind, turn: String? = nil) {
            let turnID = turn ?? cursor.turnID
            guard !turnID.isEmpty else { return }
            let event = ChatEvent(chatID: cursor.id, turnID: turnID, date: time, kind: kind, historical: historical)
            if reducer.apply(event), let chat = reducer.chats[cursor.id] {
                let token: String
                switch kind {
                case let .input(id, _): token = id
                default: token = turnID + ":" + chat.status.rawValue
                }
                notices.append((chat, token))
            }
            lastEvent = max(lastEvent ?? .distantPast, time)
        }
        if recordType == "event_msg" {
            if type == "task_started", let turn = payload["turn_id"] as? String {
                cursor.turnID = turn; emit(.started)
            } else if type == "task_complete", let turn = payload["turn_id"] as? String {
                emit(.completed, turn: turn)
            } else if type == "turn_aborted", let turn = payload["turn_id"] as? String {
                emit(.stopped, turn: turn)
            } else if ["task_failed", "turn_failed"].contains(type), let turn = payload["turn_id"] as? String {
                emit(.failed, turn: turn)
            }
        }
        guard recordType == "response_item" else { return }
        if type == "function_call", let name = payload["name"] as? String, let callID = payload["call_id"] as? String {
            let basename = name.split(separator: ".").last.map(String.init) ?? name
            if basename == "request_user_input" { emit(.input(callID, questionCount: nil)) }
            if basename == "request_user_input_async" {
                let argumentText = payload["arguments"] as? String ?? "{}"
                let arguments = (try? JSONSerialization.jsonObject(with: Data(argumentText.utf8))) as? [String: Any]
                emit(.input(callID, questionCount: (arguments?["questions"] as? [Any])?.count ?? 1))
            }
        } else if type == "function_call_output", let callID = payload["call_id"] as? String {
            if reducer.chats[cursor.id]?.pendingRequestIDs.contains(callID) == true { emit(.resolved(callID)) }
        } else if type == "message", payload["role"] as? String == "user", let content = payload["content"] as? [[String: Any]] {
            for part in content {
                guard let text = part["text"] as? String,
                      let beginning = text.range(of: "<send_user_message_question_reply>"),
                      let ending = text.range(of: "</send_user_message_question_reply>", range: beginning.upperBound..<text.endIndex),
                      let rows = try? JSONSerialization.jsonObject(with: Data(text[beginning.upperBound..<ending.lowerBound].utf8)) as? [[String: Any]] else { continue }
                for row in rows {
                    guard let key = row["questionItemId"] as? String,
                          let components = try? JSONSerialization.jsonObject(with: Data(key.utf8)) as? [Any],
                          components.count >= 3, let callID = components[1] as? String,
                          let index = components[2] as? Int else { continue }
                    emit(.answer(callID, index))
                }
            }
        }
    }
}
