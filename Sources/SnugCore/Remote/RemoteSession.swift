// 会话层的组合：连接判定 + 会话生命周期，把每拍观测变成功能模块要处理的会话变化。
// 功能模块（屏幕调度）只消费会话状态，会话层不知道有哪些功能。
// UU 同一时刻只让一台设备控制一台 Mac（实测 V12）：第二台只能「接管设备」，前一台的推流停掉 0.6～0.7 秒后新的一台起推流，
// 落在重连等待期里，算同一次远程。控制端只当作「有人在远程」的证据之一，不拿来判断设备类型。
// 登记了几家远控时，一次远程只归一家（owner），每拍只把归属方的观测交给连接判定：
// - 未连接时（空闲，或断开后的重连等待期）：归登记顺序里第一家报在场的。都不在场就保留原归属，交它这一拍的真实观测，
//   断开日志带的仍是它的信号快照
// - 已连接时：归属不变。别家也报在场，只在这次远程里头一回记一条日志，不抢
// - 重连等待期里换了一家连入：算同一次远程（resumed），屏不撤不建，推流屏、名字改取新的归属方
// - 会话结束时清空归属
// 只登记一家时，每拍交给连接判定的就是它的观测，和只有这一家时完全一样
import Foundation

public enum SessionTransition: Equatable, Sendable {
    /// 新会话开始
    case began(controllers: [String])
    /// 重连窗口内再连上，仍是同一会话
    case resumed(controllers: [String])
    case controllersChanged([String])
    /// 断开，进入重连窗口
    case interrupted
    /// 重连窗口过了，会话结束
    case ended
}

public struct RemoteSession: Sendable {
    public private(set) var tracker = ConnectionTracker()
    public private(set) var episode = SessionEpisode()
    /// 这次远程归哪家：连入时定下，会话结束时清空
    public private(set) var owner: RemoteIdentity?
    /// 连接判定这一拍跟的是哪份观测：归属方的；还没有归属时是第一家报在场的，都不在场是第一家的
    public private(set) var tracked: RemoteReading?
    /// 这次远程里已经记过「另有一家报在场」的
    private var noticed: Set<String> = []

    public init() {}

    public var isConnected: Bool { tracker.isConnected }
    /// 此刻连着的控制端（断开时为空）
    public var controllers: [String] { tracker.controllers }
    /// 这一拍从归属远控实际读到的控制端名称。路由必须用它：暂时读不到、出现多个名称时都要立即旁路，不能沿用旧名字猜设备。
    public var observedControllers: [String] { tracked?.observation.controllers ?? [] }
    public var inEpisode: Bool { episode.isActive }

    /// readings：每家登记的远控这一拍的观测，按登记顺序
    public mutating func update(_ readings: [RemoteReading], now: Date) -> [SessionTransition] {
        var out: [SessionTransition] = []
        if episode.advance(to: now) == .ended {
            out.append(.ended)
            clearOwner()
        }
        let mine = owner.flatMap { owner in readings.first { $0.remote == owner } }
        tracked = tracker.isConnected ? mine : readings.first { $0.observation.present } ?? mine ?? readings.first
        if let tracked {
            out += feed(tracked, now: now)
        }
        for t in out { Log.info(t.logLine) }
        if tracker.isConnected, let owner { noteOthers(readings, owner: owner) }
        return out
    }

    private mutating func feed(_ reading: RemoteReading, now: Date) -> [SessionTransition] {
        switch tracker.update(reading.observation, from: reading.remote.logName, now: now) {
        case .connected(let names)?:
            owner = reading.remote
            return [episode.connected(at: now) == .began ? .began(controllers: names) : .resumed(controllers: names)]
        case .controllersChanged(let names)?:
            return [.controllersChanged(names)]
        case .disconnected?:
            return episode.disconnected(at: now) == .interrupted ? [.interrupted] : []
        case nil:
            return []
        }
    }

    /// 已连接时别家也报在场：只记一条，不抢归属
    private mutating func noteOthers(_ readings: [RemoteReading], owner: RemoteIdentity) {
        for other in readings where other.remote != owner && other.observation.present {
            guard noticed.insert(other.remote.logName).inserted else { continue }
            Log.info(Self.otherPresentLine(other, owner: owner))
        }
    }

    private mutating func clearOwner() {
        owner = nil
        noticed = []
    }

    /// 用户不等重连窗口，立即结束本次会话；不在重连窗口里时什么都不做
    public mutating func endNow() -> SessionTransition? {
        guard episode.endNow() != nil else { return nil }
        clearOwner()
        Log.info(Self.endedNowLine)
        Log.info(SessionTransition.ended.logLine)
        return .ended
    }

    public mutating func noteSelfInducedChange(at date: Date) {
        tracker.noteSelfInducedChange(at: date)
    }

    /// 「立即结束」写进日志的一行（SnugLogDigest 认它是远程结束）
    static let endedNowLine = "会话：立即结束（不等重连窗口）"

    /// 已连接时别家也报在场，记下的一行
    static func otherPresentLine(_ other: RemoteReading, owner: RemoteIdentity) -> String {
        "另有 \(other.remote.logName) 报告连接，本次远程归 \(owner.logName)（\(other.observation.evidence)）"
    }
}

extension SessionTransition {
    /// 会话变化写进日志的一行。SnugLogDigest 按这些写法认远程开始、结束和控制端，往返测试钉住两边
    var logLine: String {
        switch self {
        case .began(let c): "会话：开始（控制端 \(Self.names(c))）"
        case .resumed(let c): "会话：重连上，仍是同一次远程（控制端 \(Self.names(c))）"
        case .controllersChanged(let c): "会话：控制端变为 \(Self.names(c))"
        case .interrupted: "会话：断开，等 \(Int(SessionEpisode.reconnectWindow))s 看会不会重连"
        case .ended: "会话：结束"
        }
    }

    /// 没认出控制端时日志里的写法
    static let unnamed = "读不到名字"

    private static func names(_ controllers: [String]) -> String {
        controllers.isEmpty ? unnamed : controllers.joined(separator: "、")
    }
}
