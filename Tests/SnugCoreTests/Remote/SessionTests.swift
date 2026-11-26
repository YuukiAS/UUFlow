import Foundation
import Testing
@testable import SnugCore


@Suite("会话 SessionEpisode")
struct SessionEpisodeTests {
    @Test("重连窗口 15s")
    func window() { #expect(SessionEpisode.reconnectWindow == 15) }

    @Test("连入开始会话；断开后 15s 内再连入算同一会话，超过窗口会话结束")
    func lifecycle() {
        var e = SessionEpisode()
        #expect(!e.isActive)
        #expect(e.connected(at: at(0)) == .began)
        #expect(e.disconnected(at: at(10)) == .interrupted)
        #expect(e.isActive)
        #expect(e.advance(to: at(24.9)) == nil)
        #expect(e.connected(at: at(25)) == .resumed)   // 10 + 15 = 25，还在窗口内
        #expect(e.disconnected(at: at(30)) == .interrupted)
        #expect(e.advance(to: at(45)) == nil)
        #expect(e.advance(to: at(45.1)) == .ended)
        #expect(!e.isActive)
        #expect(e.connected(at: at(50)) == .began)
    }

    @Test("重连窗口里点「立即结束」：当场结束，不再等满 15 秒（issue #29）")
    func endNow() {
        var e = SessionEpisode()
        _ = e.connected(at: at(0))
        _ = e.disconnected(at: at(1))
        #expect(e.endNow() == .ended)
        #expect(!e.isActive)
        #expect(e.advance(to: at(2)) == nil)
    }

    @Test("不在重连窗口里时「立即结束」什么都不做")
    func endNowOutsideWindow() {
        var e = SessionEpisode()
        #expect(e.endNow() == nil)
        _ = e.connected(at: at(0))
        #expect(e.endNow() == nil)
        #expect(e.isActive)
    }

    @Test("窗口过了才来的连入：先结束旧会话，再开始新会话")
    func lateReconnect() {
        var e = SessionEpisode()
        _ = e.connected(at: at(0))
        _ = e.disconnected(at: at(1))
        #expect(e.advance(to: at(17)) == .ended)
        #expect(e.connected(at: at(17)) == .began)
    }
}

@Suite("远程会话 RemoteSession")
struct RemoteSessionTests {
    private func update(_ s: inout RemoteSession, _ o: RemoteObservation, _ seconds: Double) -> [SessionTransition] {
        s.update([reading(o)], now: at(seconds))
    }

    @Test("连入 → began；断开 → interrupted；窗口内重连 → resumed；窗口过后 → ended")
    func transitions() {
        var s = RemoteSession()
        #expect(update(&s, present("iPhone"), 0) == [.began(controllers: ["iPhone"])])
        #expect(update(&s, absent, 1.0) == [])
        #expect(update(&s, absent, 2.0) == [.interrupted])
        #expect(s.isConnected == false)
        #expect(s.inEpisode)
        #expect(update(&s, present("iPhone"), 3.0) == [.resumed(controllers: ["iPhone"])])
        #expect(update(&s, absent, 5.0) == [.interrupted])
        #expect(update(&s, absent, 20.0) == [])
        #expect(update(&s, absent, 20.1) == [.ended])
        #expect(!s.inEpisode)
    }

    @Test("窗口过后同一拍又连上：先 ended 再 began")
    func endedThenBegan() {
        var s = RemoteSession()
        _ = update(&s, present("iPhone"), 0)
        _ = update(&s, absent, 2.0)
        #expect(update(&s, present("iPhone"), 30) == [.ended, .began(controllers: ["iPhone"])])
    }

    @Test("重连窗口里立即结束：透传 ended，会话随之结束（issue #29）")
    func endNow() {
        var s = RemoteSession()
        _ = update(&s, present("iPhone"), 0)
        _ = update(&s, absent, 2.0)
        #expect(s.endNow() == .ended)
        #expect(!s.inEpisode)
        #expect(update(&s, absent, 3.0) == [])
    }

    @Test("控制端变化透传为 controllersChanged")
    func controllersChanged() {
        var s = RemoteSession()
        _ = update(&s, present(), 0)
        #expect(update(&s, present("iPhone"), 0.5) == [.controllersChanged(["iPhone"])])
        #expect(s.controllers == ["iPhone"])
    }

    @Test("当前一拍读不到控制端名称时，路由看到空列表，不沿用会话里记住的旧名称")
    func observedControllersDoNotGuess() {
        var s = RemoteSession()
        _ = update(&s, present("iPhone"), 0)
        #expect(s.controllers == ["iPhone"])
        #expect(s.observedControllers == ["iPhone"])
        #expect(update(&s, present(), 0.5) == [])
        #expect(s.controllers == ["iPhone"])
        #expect(s.observedControllers.isEmpty)
    }

    @Test("回归 #1：在场却一直没认出控制端，300 秒也不断开；不在场后照常 interrupted、ended")
    func unrecognizedControllersKeepSession() {
        var s = RemoteSession()
        #expect(update(&s, present(), 0) == [.began(controllers: [])])
        for seconds in [0.5, 59.5, 60, 60.5, 75.6, 300] {
            #expect(update(&s, present(), seconds) == [])
        }
        #expect(s.inEpisode)
        #expect(update(&s, absent, 300.5) == [])
        #expect(update(&s, absent, 301.6) == [.interrupted])
        #expect(update(&s, absent, 316.7) == [.ended])
    }

    @Test("会话日志的写法逐字固定（抽出适配层前由 AppController 写，措辞一个字没改；自检按它解析）")
    func logLines() {
        #expect(SessionTransition.began(controllers: []).logLine == "会话：开始（控制端 读不到名字）")
        #expect(SessionTransition.began(controllers: ["iPhone", "iPad"]).logLine == "会话：开始（控制端 iPhone、iPad）")
        #expect(SessionTransition.resumed(controllers: ["iPhone"]).logLine == "会话：重连上，仍是同一次远程（控制端 iPhone）")
        #expect(SessionTransition.controllersChanged(["iPad"]).logLine == "会话：控制端变为 iPad")
        #expect(SessionTransition.interrupted.logLine == "会话：断开，等 15s 看会不会重连")
        #expect(SessionTransition.ended.logLine == "会话：结束")
        #expect(RemoteSession.endedNowLine == "会话：立即结束（不等重连窗口）")
        #expect(RemoteSession.otherPresentLine(reading(present("iPad"), from: otherRemote), owner: fakeRemote)
                == "另有 乙 报告连接，本次远程归 甲（在场 [\"iPad\"]）")
    }

    @Test("自扰静默期经 RemoteSession 转给 tracker")
    func selfInduced() {
        var s = RemoteSession()
        _ = update(&s, present("iPhone"), 0)
        s.noteSelfInducedChange(at: at(0))
        #expect(update(&s, absent, 4.0) == [])
        #expect(update(&s, absent, 5.1) == [.interrupted])
    }
}

@Suite("换手接管 RemoteSession")
struct HandoverTests {
    @Test("换手慢到断开了（不在场过了宽限）：还在 15 秒重连等待期里，算同一次远程（ScreenPlan 只看在不在远程，屏不撤）")
    func slowTakeover() {
        var s = RemoteSession()
        _ = s.update([reading(present())], now: at(0))
        _ = s.update([reading(present())], now: at(9.5))
        #expect(s.update([reading(absent)], now: at(10)) == [])
        #expect(s.update([reading(absent)], now: at(11.1)) == [.interrupted])
        #expect(s.inEpisode)
        #expect(s.update([reading(present())], now: at(20)) == [.resumed(controllers: [])])
        #expect(s.inEpisode)
    }
}
