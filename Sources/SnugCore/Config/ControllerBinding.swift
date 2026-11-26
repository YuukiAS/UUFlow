// UU 读到的控制端名称绑定到一块已配置屏幕；screen 为 nil 时显式旁路。
// 名称保持 UU 实际给出的原文，匹配也按原文精确匹配，避免把相似设备误认成另一台。
import Foundation

public struct ControllerBinding: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let name: String
    public var screen: ScreenID?
    /// 只在这条控制端路由生效的远程会话里，把目标屏临时设为主屏；不写入 AppConfig.mainScreen
    public var mainDuringSession: Bool

    public var id: String { name }

    public init(name: String, screen: ScreenID?, mainDuringSession: Bool = false) {
        self.name = name
        self.screen = screen
        self.mainDuringSession = screen != nil && mainDuringSession
    }

    private enum CodingKeys: String, CodingKey {
        case name, screen, mainDuringSession
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        screen = try c.decodeIfPresent(ScreenID.self, forKey: .screen)
        let requestedMain = try c.decodeIfPresent(Bool.self, forKey: .mainDuringSession) ?? false
        mainDuringSession = screen != nil && requestedMain
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(screen, forKey: .screen)
        if mainDuringSession { try c.encode(true, forKey: .mainDuringSession) }
    }
}
