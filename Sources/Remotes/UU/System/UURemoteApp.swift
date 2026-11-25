// UU远程 自身的几样直接观测：进程号、覆盖窗口在不在屏
import AppKit
import CoreGraphics
import RemoteUU
import SnugCore

@MainActor
enum UURemoteApp {
    /// 运行中的 App 列表变了才重新认 UU 的进程；每 0.5 秒一拍只读这里
    private static let watch = UUProcessWatch {
        NSWorkspace.shared.runningApplications.map {
            RunningAppIdentity(pid: $0.processIdentifier,
                               bundleID: $0.bundleIdentifier,
                               executableName: $0.executableURL?.lastPathComponent)
        }
    }
    private static var observation: NSKeyValueObservation?

    /// 开始跟踪运行中的 App。重复调用无副作用
    static func start() {
        guard observation == nil else { return }
        let watch = watch
        log(watch.processes)
        observation = NSWorkspace.shared.observe(\.runningApplications, options: [.initial, .new]) { _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { refresh(watch) } }
        }
    }

    /// UU远程 主程序的进程号；没在运行返回 nil
    static func pid() -> pid_t? { watch.processes.main }

    /// UURemoteServer（被远程时推流的后台进程）的进程号；没在运行返回 nil。它没有 bundle ID，按可执行文件名认
    static func serverPID() -> pid_t? { watch.processes.server }

    /// 后台服务能在不打开 UU 主界面的情况下拉起主进程。此时 AX 没有窗口，ControllerTable 无从读取控制端名称。
    /// 通过 Launch Services 在后台补一次正常打开事件，只让 UU 建出它自己的界面，不激活、不点击、不识别设备。
    static func openInterfaceInBackground() {
        guard let pid = pid(), let url = NSRunningApplication(processIdentifier: pid)?.bundleURL else {
            return Log.warn("UU 正在推流但主程序不可用，无法在后台打开控制端界面")
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            Task { @MainActor in
                if let error {
                    Log.warn("UU 正在推流但控制端界面读不到，后台打开失败：\(error)")
                } else {
                    Log.info("UU 正在推流但控制端界面读不到，已请求在后台打开主界面")
                }
            }
        }
    }

    private static func refresh(_ watch: UUProcessWatch) {
        guard watch.refresh() else { return }
        log(watch.processes)
    }

    private static func log(_ processes: UUProcessIDs) {
        let main = processes.main.map(String.init) ?? "没在运行"
        let server = processes.server.map(String.init) ?? "没在运行"
        Log.info("UU 进程：主程序 \(main)，后台 \(server)")
    }

    /// UURemoteServer 的覆盖窗口在屏：被远程时 UU 会在本机屏幕上放一个提示窗口
    static func overlayVisible() -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        return list.contains { ($0[kCGWindowOwnerName as String] as? String) == UURemote.serverProcess }
    }
}
