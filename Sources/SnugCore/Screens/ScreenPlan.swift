// 策略：配置 + 会话 → 此刻要哪些屏、每块的比例和行为。纯函数，规则只写在这里，换规则不动任何模块（docs/development.md「代码结构」）。
// - 只有恰好认出一个控制端、且这个名称显式绑定到一块开着的屏时才建屏；未识别、未配置、显式旁路、多名称都旁路
// - 换手时按这一拍读到的控制端重新选择，只保留新控制端绑定的那块
// - 临时主屏跟着命中的控制端规则走；旧 mainScreen 不能绕过旁路，只在显式预览模式保留
// - --preview-screens 是离线自测，仍建出所有开着的屏，不依赖控制端规则
// - 类别到行为的映射只在这里：手机、平板是触屏（屏上有面板、翻译手势、放大字号），电脑不是
import Foundation

public enum ScreenPlan {
    /// 此刻要的屏。controllers 是这一拍实际读到的控制端名称；trusted：没有辅助功能权限一块都不建；
    /// preview：不等远程、忽略控制端规则，建出所有开着的屏（--preview-screens）
    public static func wishes(config: AppConfig, remote: Bool, controllers: [String], trusted: Bool, preview: Bool = false) -> [ScreenWish] {
        guard trusted else { return [] }
        let shown = config.screens.filter(\.enabled).prefix(ScreenConfig.limit)
        let selected: ArraySlice<ScreenConfig>
        let sessionMain: ScreenID?
        if preview {
            selected = shown
            sessionMain = nil
        } else {
            guard remote, controllers.count == 1,
                  let binding = config.binding(for: controllers[0]),
                  let screenID = binding.screen,
                  let index = shown.firstIndex(where: { $0.id == screenID }) else { return [] }
            selected = shown[index...index]
            sessionMain = binding.mainDuringSession ? screenID : nil
        }
        return selected.map { screen in
            ScreenWish(id: screen.id, spec: spec(of: screen), fit: fit(of: screen), behavior: behavior(screen.device.kind),
                       main: preview ? config.mainScreen == screen.id : sessionMain == screen.id)
        }
    }

    /// 配置里的一项 → 屏的身份：竖横各一个产品号，像素上限和方向一致（V4、V5）
    public static func spec(of screen: ScreenConfig) -> ScreenSpec {
        let portrait = screen.orientation == .portrait
        return ScreenSpec(name: screen.name, productID: portrait ? ScreenSpec.portraitProductID : ScreenSpec.landscapeProductID,
                          serials: screen.serials, maxPixels: portrait ? ScreenFit.portraitPixels : ScreenFit.landscapePixels)
    }

    /// 配置里的一项 → 比例和档位
    public static func fit(of screen: ScreenConfig) -> ScreenFit { fit(screen.device, screen.orientation) }

    /// 这台设备、这个方向的比例和档位（换型号时先算出来记日志）
    public static func fit(_ device: DeviceChoice, _ orientation: Orientation) -> ScreenFit {
        ScreenFit(device: device.screen, kind: device.kind, orientation: orientation)
    }

    /// 类别 → 行为（哪些类别算触屏见 DeviceKind.isTouch）
    public static func behavior(_ kind: DeviceKind) -> ScreenBehavior {
        kind.isTouch ? .touchScreen : .computer
    }
}
