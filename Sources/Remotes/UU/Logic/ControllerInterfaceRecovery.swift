// UU 由后台服务拉起时，主程序可能只有进程、没有可读的窗口；远程已经在推流，控制端表格却会一直是 unreadable。
// 这里只决定何时请系统在后台打开 UU 主界面，让既有 ControllerTable 继续读取；不增加第二套控制端识别。
import Foundation

package struct ControllerInterfaceRecovery: Sendable {
    package static let retryAfter: TimeInterval = 5

    private var lastRequest: Date?

    package init() {}

    package mutating func shouldOpen(present: Bool, controllers: ControllerTable, now: Date) -> Bool {
        guard present else {
            lastRequest = nil
            return false
        }
        guard controllers == .unreadable else {
            lastRequest = nil
            return false
        }
        guard lastRequest.map({ now.timeIntervalSince($0) >= Self.retryAfter }) ?? true else { return false }
        lastRequest = now
        return true
    }
}
