// --check-remote uu [小时]：UU远程 兼容自检（scripts/uuflow remote-check uu 调）。收集事实交给 UUCheck 判定、打出报告，
// 并把原始材料写进 ~/Library/Logs/Snug-uu-check/（每次覆盖）：UU 的推流日志、上一次远程前后 UURemoteServer 的全部日志、
// 这段时间的 Snug 日志、UU 的界面树、哪些程序链接了抓屏与编码框架。哪项不对直接看材料，不用再一步步复现。
// 只读：不点 UU、不碰屏幕
import AppKit
import RemoteUU
import SnugCore
import SnugSystem

@MainActor
package enum UUCheckRun {
    static let evidence = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Snug-uu-check")
    /// 上一次远程的原始日志从开始前这么久取起，最多取到开始后这么久（远程开头的连入、切屏最要紧，整场太长）
    static let sessionLead: TimeInterval = 10
    static let sessionSpan: TimeInterval = 300

    package static func run(hours: Int) -> Int32 {
        let now = Date()
        let since = now.addingTimeInterval(-TimeInterval(hours) * 3600)
        var files: [String: String] = [:]

        let bundle = NSWorkspace.shared.urlForApplication(withBundleIdentifier: UURemote.bundleID)
        let version = bundle.flatMap { Bundle(url: $0)?.infoDictionary?["CFBundleShortVersionString"] as? String }
        let scan = bundle.map(scanBundle) ?? (servers: [], linkers: [:])
        files["uu-binaries.txt"] = ([bundle.map { "UU远程：\($0.path)（\(version ?? "版本未知")）" } ?? "UU远程：没装"]
            + scan.linkers.sorted { $0.key < $1.key }.map { "\($0.key)：\($0.value.joined(separator: "、"))" }
            + ["\(UURemote.serverProcess)：\(scan.servers.joined(separator: "、"))"]).joined(separator: "\n")

        let captureLog = showLog(["--last", "\(hours)h", "--predicate", CaptureLogParser.predicate])
        var capture: [CaptureLogRecord]?
        if let captureLog {
            var buffer = CaptureLogLineBuffer()
            capture = buffer.feed(Data(captureLog.utf8)) + buffer.finish()
            files["uu-capture.ndjson"] = captureLog
        }

        let snugLines = readSnugLog()
        let snug = SnugLogDigest(lines: snugLines, since: since, remote: UURemote.identity.logName)
        files["snug.log"] = SnugLogDigest.recent(snugLines, since: since).joined(separator: "\n")
        if let start = snug.sessionStarts.last {
            let end = min(snug.sessionEnds.first { $0 > start }.map { $0 + 15 } ?? now, start + sessionSpan)
            files["uu-server-last-session.ndjson"] = showLog(["--start", logTime(start - sessionLead), "--end", logTime(end),
                                                             "--predicate", "process == \"\(UURemote.serverProcess)\""])
        }

        let pid = UURemoteApp.pid()
        var table: ControllerTable?
        if AX.isTrusted, let pid {
            let windows = UUAccessibility.windows(pid: pid)
            table = windows.map(ControllerTable.init) ?? .unreadable
            files["uu-ax-tree.txt"] = windows.map { UUDump.treeLines($0).joined(separator: "\n") } ?? "读不到（UU 没有窗口、没响应，或界面超出遍历上限）"
        }
        files["displays.txt"] = UUDump.displayLines().joined(separator: "\n")
        let onlineSnug = Set((Screens.online() ?? []).filter { CGDisplayVendorNumber($0) == ScreenSpec.vendorID })
        let server = UURemoteApp.serverPID().map { UUCheck.Server(pid: $0, start: processStart($0)) }

        let facts = UUCheck.Facts(hours: hours, since: since, version: version, appRunning: pid != nil, server: server,
                                  serverExecutables: scan.servers, linkers: scan.linkers, capture: capture, snugLog: snugLines.map(String.init),
                                  onlineSnugDisplays: onlineSnug, controllersNow: table)
        let items = UUCheck.evaluate(facts)
        let report = UUCheck.report(items, hours: hours, at: now)
        files["report.txt"] = report
        print(report)
        print("")
        print(writeEvidence(files))
        return items.contains { $0.status == .fail } ? 1 : 0
    }

    // MARK: 收集

    /// UU 包里的 Mach-O 程序：哪些叫 UURemoteServer，哪些链接了抓屏、编码框架（按加载命令里的框架路径认，不依赖 otool）
    private static func scanBundle(_ bundle: URL) -> (servers: [String], linkers: [String: [String]]) {
        let needles = [UUCheck.captureFramework, UUCheck.encoderFramework].map { ($0, Data("/System/Library/Frameworks/\($0).framework/".utf8)) }
        var servers: [String] = []
        var linkers: [String: [String]] = [:]
        let walker = FileManager.default.enumerator(at: bundle, includingPropertiesForKeys: [.isRegularFileKey])
        while let url = walker?.nextObject() as? URL {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true,
                  let data = try? Data(contentsOf: url, options: .alwaysMapped), isMachO(data) else { continue }
            let path = String(url.path.dropFirst(bundle.path.count + 1))
            if url.lastPathComponent == UURemote.serverProcess { servers.append(path) }
            for (name, needle) in needles where data.range(of: needle) != nil { linkers[name, default: []].append(path) }
        }
        return (servers.sorted(), linkers.mapValues { $0.sorted() })
    }

    /// 进程启动的时刻（内核记的）；读不到为 nil
    private static func processStart(_ pid: pid_t) -> Date? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec) + TimeInterval(info.pbi_start_tvusec) / 1_000_000)
    }

    private static func isMachO(_ data: Data) -> Bool {
        let magics: [[UInt8]] = [[0xCF, 0xFA, 0xED, 0xFE], [0xCE, 0xFA, 0xED, 0xFE], [0xCA, 0xFE, 0xBA, 0xBE], [0xCA, 0xFE, 0xBA, 0xBF]]
        return data.count >= 4 && magics.contains { data.prefix(4).elementsEqual($0) }
    }

    /// `log show … --style ndjson`；失败时在标准错误说明原因，返回 nil。
    /// 标准错误并进同一根管子：分两根依次读的话，一根写满会把另一根卡死；解析只认 JSON 行，混进来的提示不影响
    private static func showLog(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = ["show", "--style", "ndjson"] + arguments
        let out = Pipe()
        process.standardOutput = out
        process.standardError = out
        do {
            try process.run()
        } catch {
            FileHandle.standardError.write(Data("log show 启动失败：\(error)\n".utf8))
            return nil
        }
        let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            FileHandle.standardError.write(Data("log show 失败（状态 \(process.terminationStatus)）：\(text.suffix(500))\n".utf8))
            return nil
        }
        return text
    }

    private static func logTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }

    /// 滚动过的旧日志在前（见 FileLogSink），读不到的跳过
    private static func readSnugLog() -> [Substring] {
        let current = SnugPaths.standard.logFile
        let rotated = current.deletingLastPathComponent().appendingPathComponent(current.lastPathComponent + ".1")
        return [rotated, current].flatMap { url -> [Substring] in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
            return text.split(separator: "\n")
        }
    }

    /// 整个目录换成这次的材料；写不进去时说明原因（报告已经打出来了，不因此失败）
    private static func writeEvidence(_ files: [String: String]) -> String {
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: evidence.path) { try fm.removeItem(at: evidence) }
            try fm.createDirectory(at: evidence, withIntermediateDirectories: true)
            for (name, content) in files {
                try Data(content.utf8).write(to: evidence.appendingPathComponent(name))
            }
            return "取证材料：\(evidence.path)（\(files.keys.sorted().joined(separator: "、"))）"
        } catch {
            return "取证材料写不进 \(evidence.path)：\(error)"
        }
    }
}
