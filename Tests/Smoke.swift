import Foundation

@main
struct Smoke {
    static func main() {
        var reducer = ChatReducer()
        reducer.chats["a"] = ChatState(id: "a", title: "A", project: "Test")
        reducer.chats["b"] = ChatState(id: "b", title: "B", project: "Test")
        var tick = 0.0
        func event(_ id: String, _ turn: String, _ kind: ChatEvent.Kind) -> ChatEvent {
            tick += 1
            return ChatEvent(chatID: id, turnID: turn, date: Date(timeIntervalSince1970: tick), kind: kind)
        }
        reducer.apply(event("a", "1", .started))
        reducer.apply(event("b", "2", .started))
        reducer.apply(event("a", "1", .input("q", questionCount: 1)))
        assert(reducer.aggregate == .attention)
        reducer.apply(event("a", "1", .resolved("q")))
        assert(reducer.chats["a"]?.status == .attention, "Async delivery is not a human answer")
        reducer.apply(event("a", "1", .answer("q", 0)))
        assert(reducer.aggregate == .working)
        reducer.apply(event("a", "1", .completed))
        assert(reducer.aggregate == .working && reducer.chats["a"]?.status == .ready)
        reducer.apply(event("a", "1", .started))
        assert(reducer.chats["a"]?.status == .ready, "Duplicate start must not resurrect terminal turn")
        reducer.apply(event("a", "old", .completed))
        assert(reducer.chats["a"]?.status == .ready, "Stale turn must not change state")
        reducer.markRead("a")
        assert(reducer.chats["a"]?.status == .idle)
        reducer.apply(event("b", "2", .input("sync", questionCount: nil)))
        reducer.apply(event("b", "2", .resolved("other")))
        assert(reducer.chats["b"]?.status == .attention)
        reducer.apply(event("b", "2", .resolved("sync")))
        assert(reducer.chats["b"]?.status == .working)
        reducer.apply(event("b", "2", .stopped))
        assert(reducer.chats["b"]?.status == .stopped)
        print("Reducer smoke passed")
    }
}
