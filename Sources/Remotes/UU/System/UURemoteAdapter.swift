// UU远程 的适配器：每拍合成一份观测：覆盖窗口（同步查）、控制端表格（后台读）、推流（日志子进程）
import Foundation
import RemoteUU
import SnugCore
import SnugSystem

@MainActor
package final class UURemoteAdapter: RemoteAdapter {
    package static let identity = UURemote.identity
    private let controllers = ControllerReader()
    private let captureLog = CaptureLogWatcher()
    private var interfaceRecovery = ControllerInterfaceRecovery()

    package init() {}

    package func start() {
        UURemoteApp.start()
        captureLog.start()
    }
    package func stop() { captureLog.stop() }

    package func sample(wallClock: Date) -> RemoteObservation {
        let capture = captureLog.sample(at: wallClock)
        let overlay = UURemoteApp.overlayVisible()
        let table = controllers.poll()
        if AX.isTrusted,
           interfaceRecovery.shouldOpen(present: overlay || capture.active == true, controllers: table, now: wallClock) {
            UURemoteApp.openInterfaceInBackground()
        }
        return UUSignals(overlayVisible: overlay, controllers: table, captureActive: capture.active)
            .observation(streamedDisplay: capture.display)
    }
}
