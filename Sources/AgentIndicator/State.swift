import Foundation

enum TaskStatus: String, CaseIterable {
    case idle, working, attention, ready, stopped, unavailable
    var label: String {
        switch self {
        case .idle: return "Idle"
        case .working: return "Working"
        case .attention: return "Needs you"
        case .ready: return "Response ready"
        case .stopped: return "Stopped"
        case .unavailable: return "Status unavailable"
        }
    }
    var symbol: String {
        switch self {
        case .idle: return "circle"
        case .working: return "circle.dotted"
        case .attention: return "hand.raised.fill"
        case .ready: return "checkmark.circle.fill"
        case .stopped: return "stop.circle"
        case .unavailable: return "exclamationmark.triangle"
        }
    }
    var priority: Int {
        switch self {
        case .attention: return 5
        case .working: return 4
        case .ready: return 3
        case .unavailable: return 2
        case .stopped: return 1
        case .idle: return 0
        }
    }
    func lightIsOn(at elapsed: TimeInterval) -> Bool {
        switch self {
        case .working: return elapsed.truncatingRemainder(dividingBy: 0.8) < 0.4
        case .attention:
            let phase = elapsed.truncatingRemainder(dividingBy: 1.5)
            return phase < 0.15 || (phase >= 0.3 && phase < 0.45) || (phase >= 0.6 && phase < 0.75)
        case .ready: return elapsed.truncatingRemainder(dividingBy: 3) < 2.7
        default: return false
        }
    }
}

struct ChatState: Identifiable {
    let id: String
    var title: String
    var project: String
    var turnID: String = ""
    var status: TaskStatus = .unavailable
    var updatedAt = Date.distantPast
    var pendingRequestIDs: Set<String> = []
    var detail = ""
    var terminal = false
    var asynchronousQuestions: [String: Set<Int>] = [:]
}

struct ChatEvent {
    enum Kind {
        case started, completed, stopped, failed
        case input(String, questionCount: Int?)
        case resolved(String)
        case answer(String, Int)
    }
    let chatID: String
    let turnID: String
    let date: Date
    let kind: Kind
    var historical = false
}

struct ChatReducer {
    var chats: [String: ChatState] = [:]
    var aggregate: TaskStatus {
        chats.values.map(\.status).max(by: { $0.priority < $1.priority }) ?? .idle
    }
    mutating func markRead(_ id: String) {
        guard chats[id]?.status == .ready else { return }
        chats[id]?.status = .idle
        chats[id]?.detail = ""
    }
    @discardableResult
    mutating func apply(_ event: ChatEvent) -> Bool {
        guard var chat = chats[event.chatID], event.date >= chat.updatedAt else { return false }
        let previous = chat.status
        switch event.kind {
        case .started:
            if chat.turnID == event.turnID { return false }
            chat.turnID = event.turnID
            chat.terminal = false
            chat.pendingRequestIDs.removeAll()
            chat.asynchronousQuestions.removeAll()
            chat.status = .working
            chat.detail = ""
        default:
            // A terminal record can reconstruct a bounded tail without its earlier start.
            if chat.turnID.isEmpty {
                switch event.kind {
                case .completed, .stopped, .failed: chat.turnID = event.turnID
                default: return false
                }
            }
            guard chat.turnID == event.turnID, !chat.terminal else { return false }
            switch event.kind {
            case .completed, .stopped, .failed:
                chat.terminal = true
                chat.pendingRequestIDs.removeAll()
                chat.asynchronousQuestions.removeAll()
                switch event.kind {
                case .completed: chat.status = event.historical ? .idle : .ready
                case .stopped: chat.status = .stopped
                default: chat.status = .attention; chat.detail = "Turn failed"
                }
            case let .input(requestID, count):
                chat.pendingRequestIDs.insert(requestID)
                if let count { chat.asynchronousQuestions[requestID] = Set(0..<max(1, count)) }
                chat.status = .attention
                chat.detail = "Question waiting for your answer"
            case let .resolved(requestID):
                // Async tool return only acknowledges delivery, not a human answer.
                if chat.asynchronousQuestions[requestID] == nil { chat.pendingRequestIDs.remove(requestID) }
                chat.status = chat.pendingRequestIDs.isEmpty ? .working : .attention
                if chat.pendingRequestIDs.isEmpty { chat.detail = "" }
            case let .answer(requestID, index):
                guard chat.asynchronousQuestions[requestID] != nil else { return false }
                chat.asynchronousQuestions[requestID]?.remove(index)
                if chat.asynchronousQuestions[requestID]?.isEmpty == true {
                    chat.asynchronousQuestions.removeValue(forKey: requestID)
                    chat.pendingRequestIDs.remove(requestID)
                }
                chat.status = chat.pendingRequestIDs.isEmpty ? .working : .attention
                if chat.pendingRequestIDs.isEmpty { chat.detail = "" }
            case .started: break
            }
        }
        chat.updatedAt = event.date
        chats[event.chatID] = chat
        return !event.historical && chat.status != previous && (chat.status == .attention || chat.status == .ready)
    }
}
