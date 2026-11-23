import Testing
@testable import SnugCore

@Suite("策略 ScreenPlan")
struct ScreenPlanTests {
    private let ipad = DeviceChoice(model: "Apple iPad（A16）", screen: DeviceScreen(width: 1640, height: 2360, points: 820), kind: .tablet)
    private let air = DeviceChoice(model: "Apple MacBook Air 13 英寸（M4）", screen: DeviceScreen(width: 956, height: 1470, notch: 33), kind: .computer)
    private let remote = true
    private let legion = "LEGION-Y9000P"
    private let phone = "Alice iPhone"
    private let tablet = "Alice iPad"
    private let neo = "MacBook Neo"

    /// 手机竖屏 + iPad 横屏 + Neo 电脑屏，以及四条控制端规则
    private func config() -> AppConfig {
        var c = AppConfig()
        c.addScreen(orientation: .landscape, device: ipad)
        c.addScreen(orientation: .landscape, device: air, name: "Neo 电脑屏")
        c.bindController(legion, to: nil)
        c.bindController(phone, to: .phone)
        c.bindController(tablet, to: c.screens[1].id)
        c.bindController(neo, to: c.screens[2].id)
        return c
    }

    @Test("Legion 显式旁路；未识别、未配置、同时出现多个控制端也都旁路")
    func bypasses() {
        let c = config()
        #expect(ScreenPlan.wishes(config: c, remote: remote, controllers: [legion], trusted: true).isEmpty)
        #expect(ScreenPlan.wishes(config: c, remote: remote, controllers: [], trusted: true).isEmpty)
        #expect(ScreenPlan.wishes(config: c, remote: remote, controllers: ["未配置设备"], trusted: true).isEmpty)
        #expect(ScreenPlan.wishes(config: c, remote: remote, controllers: [phone, legion], trusted: true).isEmpty)
    }

    @Test("手机、iPad、Neo 各只创建绑定的那一块屏")
    func oneBoundScreen() {
        let c = config()
        let phoneWishes = ScreenPlan.wishes(config: c, remote: remote, controllers: [phone], trusted: true)
        let tabletWishes = ScreenPlan.wishes(config: c, remote: remote, controllers: [tablet], trusted: true)
        let neoWishes = ScreenPlan.wishes(config: c, remote: remote, controllers: [neo], trusted: true)
        #expect(phoneWishes.map(\.id) == [.phone])
        #expect(tabletWishes.map(\.id) == [c.screens[1].id])
        #expect(neoWishes.map(\.id) == [c.screens[2].id])
        #expect(phoneWishes[0].spec == ScreenPlan.spec(of: c.screens[0]))
        #expect(tabletWishes[0].fit == ScreenPlan.fit(of: c.screens[1]))
    }

    @Test("控制端接管后，策略只保留新控制端绑定的屏")
    func takeover() {
        let c = config()
        #expect(ScreenPlan.wishes(config: c, remote: remote, controllers: [phone], trusted: true).map(\.id) == [.phone])
        #expect(ScreenPlan.wishes(config: c, remote: remote, controllers: [neo], trusted: true).map(\.id) == [c.screens[2].id])
        #expect(ScreenPlan.wishes(config: c, remote: remote, controllers: [legion], trusted: true).isEmpty)
    }

    @Test("不在远程、没有辅助功能权限：一块都不要；预览模式不依赖控制端，仍建所有开着的屏")
    func gates() {
        let c = config()
        #expect(ScreenPlan.wishes(config: c, remote: false, controllers: [phone], trusted: true).isEmpty)
        #expect(ScreenPlan.wishes(config: c, remote: remote, controllers: [phone], trusted: false).isEmpty)
        #expect(ScreenPlan.wishes(config: c, remote: false, controllers: [], trusted: true, preview: true).count == 3)
        #expect(ScreenPlan.wishes(config: c, remote: false, controllers: [], trusted: false, preview: true).isEmpty)
    }

    @Test("类别 → 行为：手机、平板是触屏，电脑不是；手势总开关不改行为（翻不翻译由界面层按开关定）")
    func behavior() {
        #expect(ScreenPlan.behavior(.phone) == .touchScreen)
        #expect(ScreenPlan.behavior(.tablet) == .touchScreen)
        #expect(ScreenPlan.behavior(.computer) == .computer)
        var c = config()
        let phoneWish = ScreenPlan.wishes(config: c, remote: remote, controllers: [phone], trusted: true)
        let tabletWish = ScreenPlan.wishes(config: c, remote: remote, controllers: [tablet], trusted: true)
        let computerWish = ScreenPlan.wishes(config: c, remote: remote, controllers: [neo], trusted: true)
        c.gestures = false
        #expect(ScreenPlan.wishes(config: c, remote: remote, controllers: [phone], trusted: true) == phoneWish)
        #expect([phoneWish[0].behavior.touch, tabletWish[0].behavior.touch, computerWish[0].behavior.touch] == [true, true, false])
    }

    @Test("身份按方向：竖屏 0xF0、横屏 0xF1，像素上限跟着方向；迁移来的那块沿用老身份")
    func identity() {
        let c = config()
        let phoneWishes = ScreenPlan.wishes(config: c, remote: remote, controllers: [phone], trusted: true)
        let tabletWishes = ScreenPlan.wishes(config: c, remote: remote, controllers: [tablet], trusted: true)
        #expect(phoneWishes[0].spec.productID == ScreenSpec.portraitProductID)
        #expect(phoneWishes[0].spec.maxPixels == ScreenFit.portraitPixels)
        #expect(phoneWishes[0].spec.serials == [200_000_108, 200_000_118, 200_000_128])
        #expect(phoneWishes[0].spec.name == "Snug 手机屏")
        #expect(tabletWishes[0].spec.productID == ScreenSpec.landscapeProductID)
        #expect(tabletWishes[0].spec.maxPixels == ScreenFit.landscapePixels)
    }

    @Test("真实远程停用设为主屏，不能绕过旁路或额外搬窗口；显式预览仍保留旧行为")
    func main() {
        var c = config()
        c.mainScreen = c.screens[1].id
        #expect(ScreenPlan.wishes(config: c, remote: remote, controllers: [tablet], trusted: true).map(\.main) == [false])
        #expect(ScreenPlan.wishes(config: c, remote: remote, controllers: [legion], trusted: true).isEmpty)
        #expect(ScreenPlan.wishes(config: c, remote: false, controllers: [], trusted: true).isEmpty)
        #expect(ScreenPlan.wishes(config: c, remote: false, controllers: [], trusted: true, preview: true).map(\.main) == [false, true, false])
    }

    @Test("加到上限就不再加；手改配置开了更多块：只建前 4 块")
    func limit() {
        var c = AppConfig()
        for _ in 1..<ScreenConfig.limit { #expect(c.addScreen(orientation: .portrait, device: .standard) != nil) }
        #expect(c.addScreen(orientation: .portrait, device: .standard) == nil)
        c.screens.append(ScreenConfig(id: .make(), orientation: .portrait, device: .standard, enabled: true, name: "手改的", serials: [1]))
        #expect(ScreenPlan.wishes(config: c, remote: false, controllers: [], trusted: true, preview: true).count == ScreenConfig.limit)
    }
}

@Suite("屏幕列表 ScreenConfig")
struct ScreenConfigTests {
    @Test("按型号起名：去掉代际和尺寸；每类设备平常的方向不加后缀，反过来的写明横竖；自己填的、通用分辨率按类别叫")
    func suggestedName() {
        func name(_ model: String?, _ kind: DeviceKind, _ o: Orientation) -> String {
            ScreenConfig.suggestedName(for: DeviceChoice(model: model, screen: DeviceScreen(width: 9, height: 20), kind: kind), orientation: o)
        }
        #expect(name("Apple iPhone 17 Pro Max", .phone, .portrait) == "Snug iPhone 17 Pro Max")
        #expect(name("Apple iPhone 17 Pro Max", .phone, .landscape) == "Snug iPhone 17 Pro Max 横屏")
        #expect(name("Apple iPad（第 10 代）", .tablet, .landscape) == "Snug iPad")
        #expect(name("Apple iPad Pro 11 英寸（M5）", .tablet, .portrait) == "Snug iPad Pro 竖屏")
        #expect(name("Apple MacBook Air 13 英寸（M4）", .computer, .landscape) == "Snug MacBook Air")
        #expect(name("华为 MatePad Pro 13.2 英寸", .tablet, .landscape) == "Snug 华为 MatePad Pro")
        #expect(name("通用 1920 × 1080", .computer, .landscape) == "Snug 电脑")
        #expect(name(nil, .tablet, .landscape) == "Snug 平板")
        #expect(name(nil, .phone, .portrait) == "Snug 手机")
    }
}
