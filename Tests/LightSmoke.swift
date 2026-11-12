import Foundation

@main
struct LightSmoke {
    static func main() {
        for offset in [0.0, 24.0] {
            assert(TaskStatus.working.lightIsOn(at: offset + 0.1))
            assert(!TaskStatus.working.lightIsOn(at: offset + 0.6))
            assert(TaskStatus.working.lightIsOn(at: offset + 0.9))
            assert(TaskStatus.attention.lightIsOn(at: offset + 0.1))
            assert(!TaskStatus.attention.lightIsOn(at: offset + 0.2))
            assert(TaskStatus.attention.lightIsOn(at: offset + 0.35))
            assert(!TaskStatus.attention.lightIsOn(at: offset + 0.5))
            assert(TaskStatus.attention.lightIsOn(at: offset + 0.65))
            assert(!TaskStatus.attention.lightIsOn(at: offset + 1.1))
            assert(TaskStatus.ready.lightIsOn(at: offset + 2.5))
            assert(!TaskStatus.ready.lightIsOn(at: offset + 2.85))
        }
        assert(!TaskStatus.idle.lightIsOn(at: 0.1))
        print("Light pattern smoke passed")
    }
}
