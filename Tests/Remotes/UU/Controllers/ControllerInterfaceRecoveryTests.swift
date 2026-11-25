import Foundation
import Testing
@testable import RemoteUU

@Suite("UU 控制端界面恢复 ControllerInterfaceRecovery")
struct ControllerInterfaceRecoveryTests {
    @Test("远程已在进行但控制端界面读不到时请求后台打开；成功读到后可在再次失读时重试")
    func opensWhenRemoteInterfaceIsUnreadable() {
        let start = Date(timeIntervalSince1970: 100)
        var recovery = ControllerInterfaceRecovery()

        let first = recovery.shouldOpen(present: true, controllers: .unreadable, now: start)
        let tooSoon = recovery.shouldOpen(present: true, controllers: .unreadable, now: start.addingTimeInterval(1))
        let readable = recovery.shouldOpen(present: true, controllers: .shown(["MacBook-Neo"]), now: start.addingTimeInterval(2))
        let unreadableAgain = recovery.shouldOpen(present: true, controllers: .unreadable, now: start.addingTimeInterval(3))

        #expect(first)
        #expect(!tooSoon)
        #expect(!readable)
        #expect(unreadableAgain)
    }

    @Test("界面可读但没认出控制端时不打开；持续失读按间隔重试；远程结束后清状态")
    func retriesOnlyWhileUnreadableAndPresent() {
        let start = Date(timeIntervalSince1970: 200)
        var recovery = ControllerInterfaceRecovery()

        let unrecognized = recovery.shouldOpen(present: true, controllers: .unrecognized, now: start)
        let first = recovery.shouldOpen(present: true, controllers: .unreadable, now: start)
        let tooSoon = recovery.shouldOpen(present: true, controllers: .unreadable, now: start.addingTimeInterval(4))
        let retry = recovery.shouldOpen(present: true, controllers: .unreadable, now: start.addingTimeInterval(5))
        let absent = recovery.shouldOpen(present: false, controllers: .unreadable, now: start.addingTimeInterval(6))
        let nextSession = recovery.shouldOpen(present: true, controllers: .unreadable, now: start.addingTimeInterval(7))

        #expect(!unrecognized)
        #expect(first)
        #expect(!tooSoon)
        #expect(retry)
        #expect(!absent)
        #expect(nextSession)
    }
}
