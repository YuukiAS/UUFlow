// UU 读到的控制端名称绑定到一块已配置屏幕；screen 为 nil 时显式旁路。
// 名称保持 UU 实际给出的原文，匹配也按原文精确匹配，避免把相似设备误认成另一台。
import Foundation

public struct ControllerBinding: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let name: String
    public var screen: ScreenID?

    public var id: String { name }

    public init(name: String, screen: ScreenID?) {
        self.name = name
        self.screen = screen
    }
}
