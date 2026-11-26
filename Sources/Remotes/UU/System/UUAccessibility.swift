// 通过辅助功能接口把 UU远程 的窗口照原样抄成界面树，交给 ControllerTable 认控制端（认哪一页、哪张表都在那里，这里不解释）。
// 只读，不点 UU 的任何东西，不为了读表格把 UU 的窗口弹出来或切页面：读不到、没认出都照常远程，只是少了一路在场证据和控制端名字（读不到按手机处理）。
// 没有窗口时读不到。
// AX 调用会阻塞（UU 卡顿时每次最多等 1 秒），所以这里的函数都是同步的，只在后台队列调用，绝不在主线程。
// 进程号由调用方在主线程查好传进来，后台只碰 AX，不碰 AppKit
import ApplicationServices
import RemoteUU
import SnugCore
import SnugSystem

enum UUAccessibility {
    /// AX 树有环，跳过环之外再限制深度和节点数；超限按「读不到」处理，不拿半截结果当真
    static let maxDepth = 25
    static let maxNodes = 2048

    /// UU 每个窗口的界面树。没有窗口或超出上限时返回 nil
    static func windows(pid: pid_t) -> [UUElement]? {
        let wins = windowElements(pid: pid)
        guard !wins.isEmpty else { return nil }
        var walk = Walk()
        return try? wins.compactMap { try snapshot($0, walk: &walk) }
    }

    /// 只在快照已经确认左侧存在「本机被控中」卡片、详情表格却没展开时调用。
    /// 点精确标题或离它最近、支持 AXPress 的容器；不按设备名、不碰其他设备详情。
    static func revealLocalControllerPage(pid: pid_t) -> Bool {
        var walk = RevealWalk()
        return windowElements(pid: pid).contains { reveal(in: $0, ancestors: [], walk: &walk) }
    }

    // MARK: AX 基础（薄封装在 SnugSystem 的 AX）

    private static func role(_ el: AXUIElement) -> String? { AX.string(el, kAXRoleAttribute) }
    private static func value(_ el: AXUIElement) -> String? { AX.string(el, kAXValueAttribute) }

    /// 一次读角色、文字和子节点；批量接口整体失败时退回逐个读
    private static let nodeAttributes = [kAXRoleAttribute, kAXValueAttribute, kAXChildrenAttribute]

    /// 窗口列表之外再读主窗口和焦点窗口：别的 App 占着全屏 Space 时，UU 的 AXWindows 可能是空的，
    /// 主窗口引用却还有效。按 AX 对象去重，不激活 UU、不切 Space（思路来自社区 PR #10，作者 Rongzheng Liu）
    private static func windowElements(pid: pid_t) -> [AXUIElement] {
        let app = AX.application(pid)
        var result = (AX.attribute(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
        for key in [kAXMainWindowAttribute, kAXFocusedWindowAttribute] {
            guard let raw = AX.attribute(app, key), CFGetTypeID(raw) == AXUIElementGetTypeID() else { continue }
            let window = raw as! AXUIElement
            guard role(window) == kAXWindowRole, !result.contains(where: { CFEqual($0, window) }) else { continue }
            result.append(window)
        }
        return result
    }

    private struct TooLarge: Error {}

    private struct Walk {
        /// 从窗口到当前元素的这一串：再碰到其中一个就是环
        var path = Set<AXUIElement>()
        var count = 0
    }

    private struct RevealWalk {
        var path = Set<AXUIElement>()
        var count = 0
    }

    private static func reveal(in node: AXUIElement, ancestors: [AXUIElement], walk: inout RevealWalk) -> Bool {
        guard !walk.path.contains(node), ancestors.count < maxDepth, walk.count < maxNodes else { return false }
        walk.count += 1
        walk.path.insert(node)
        defer { walk.path.remove(node) }

        if role(node) == kAXStaticTextRole, value(node) == ControllerTable.pageTitle {
            for target in [node] + ancestors.reversed().prefix(4) where press(target) { return true }
        }
        return AX.children(node).contains { reveal(in: $0, ancestors: ancestors + [node], walk: &walk) }
    }

    private static func press(_ element: AXUIElement) -> Bool {
        var raw: CFArray?
        guard AXUIElementCopyActionNames(element, &raw) == .success,
              let actions = raw as? [String], actions.contains(kAXPressAction) else { return false }
        return AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }

    /// 先序抄下来。只跳过环，不按对象去重：同一个元素挂在两个父元素下就两处都抄，
    /// 「标题和表格挂在同一个元素下」这层关系不会因为先在别处抄过而丢掉。超过深度或节点上限时抛错
    private static func snapshot(_ node: AXUIElement, walk: inout Walk) throws -> UUElement? {
        guard !walk.path.contains(node) else { return nil }
        walk.count += 1
        guard walk.path.count < maxDepth, walk.count <= maxNodes else { throw TooLarge() }
        walk.path.insert(node)
        defer { walk.path.remove(node) }
        let (kind, nodes) = read(node)
        let children = try nodes.compactMap { try snapshot($0, walk: &walk) }
        return UUElement(kind, children)
    }

    private static func read(_ node: AXUIElement) -> (kind: UUElement.Kind, children: [AXUIElement]) {
        if let values = AX.attributes(node, nodeAttributes), values.count >= 3 {
            return (kind(role: values[0] as? String, value: values[1] as? String),
                    children(values[2], of: node))
        }
        // 批量接口整体失败：退回逐个读
        return (kind(role: role(node), value: value(node)), AX.children(node))
    }

    /// 子节点：CFNull 或 AXValue 的错误都按没有子节点处理（和逐个读的失败结果一致）；意外的类型退回逐个读
    private static func children(_ value: AnyObject, of node: AXUIElement) -> [AXUIElement] {
        if let children = value as? [AXUIElement] { return children }
        if value is NSNull { return [] }
        if CFGetTypeID(value) == AXValueGetTypeID(), AXValueGetType(value as! AXValue) == .axError { return [] }
        return AX.children(node)
    }

    private static func kind(role: String?, value: String?) -> UUElement.Kind {
        switch role {
        case kAXStaticTextRole: value.map(UUElement.Kind.text) ?? .other
        case kAXTableRole: .table
        case kAXRowRole: .row
        default: .other
        }
    }
}
