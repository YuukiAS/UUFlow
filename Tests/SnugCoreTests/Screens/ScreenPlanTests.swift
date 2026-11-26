import CoreGraphics
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
        c.bindController(neo, to: c.screens[2].id, mainDuringSession: true)
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
        #expect(phoneWishes.map(\.main) == [false])
        #expect(tabletWishes.map(\.main) == [false])
        #expect(neoWishes.map(\.main) == [true])
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

    @Test("真实远程只采用控制端规则的临时主屏；旧 mainScreen 不能绕过旁路，显式预览仍保留旧行为")
    func main() {
        var c = config()
        c.mainScreen = c.screens[1].id
        #expect(ScreenPlan.wishes(config: c, remote: remote, controllers: [tablet], trusted: true).map(\.main) == [false])
        #expect(ScreenPlan.wishes(config: c, remote: remote, controllers: [neo], trusted: true).map(\.main) == [true])
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

@Suite("一加、iPad、ThinkPad 与 MacBook Neo 精确路由")
struct DeviceRoutingTests {
    private let onePlusName = "一加 12 全网通版"
    private let ipadName = "iPad Air 5"
    private let thinkPadName = "THINKPAD-E16"
    private let neoName = "MacBook-Neo"
    private let legionName = "LEGION-Y9000P"
    private let onePlusID = ScreenID("oneplus-landscape")
    private let ipadID = ScreenID("ipad-air-m1")
    private let thinkPadID = ScreenID("thinkpad-e16")
    private let neoID = ScreenID("macbook-neo")

    private func config() -> AppConfig {
        var c = AppConfig()
        c.screens = [
            ScreenConfig(
                id: onePlusID,
                orientation: .landscape,
                device: DeviceChoice(
                    model: "一加 12",
                    screen: DeviceScreen(width: 1440, height: 3168),
                    kind: .phone
                ),
                name: "Snug 一加 12 横屏",
                serials: [1]
            ),
            ScreenConfig(
                id: ipadID,
                orientation: .landscape,
                device: DeviceChoice(
                    model: "Apple iPad Air（第 5 代）",
                    screen: DeviceScreen(width: 1640, height: 2360, points: 820),
                    kind: .tablet
                ),
                name: "iPad Air M1",
                serials: [2]
            ),
            ScreenConfig(
                id: thinkPadID,
                orientation: .landscape,
                device: DeviceChoice(
                    model: nil,
                    screen: DeviceScreen(width: 720, height: 1280),
                    kind: .computer
                ),
                name: "ThinkPad E16",
                serials: [3]
            ),
            ScreenConfig(
                id: neoID,
                orientation: .landscape,
                device: DeviceChoice(
                    model: nil,
                    screen: DeviceScreen(width: 881, height: 1408),
                    kind: .computer
                ),
                name: "MacBook Neo",
                serials: [4]
            ),
        ]
        c.bindController(onePlusName, to: onePlusID)
        c.bindController(ipadName, to: ipadID)
        c.bindController(thinkPadName, to: thinkPadID)
        c.bindController(neoName, to: neoID, mainDuringSession: true)
        c.bindController(legionName, to: nil)
        return c
    }

    private func selected(_ controllers: [String], remote: Bool = true, config: AppConfig? = nil) -> [ScreenID] {
        ScreenPlan.wishes(
            config: config ?? self.config(),
            remote: remote,
            controllers: controllers,
            trusted: true
        ).map(\.id)
    }

    @Test("四个真实名称各只选中自己的屏")
    func exactNames() {
        #expect(selected([onePlusName]) == [onePlusID])
        #expect(selected([ipadName]) == [ipadID])
        #expect(selected([thinkPadName]) == [thinkPadID])
        #expect(selected([neoName]) == [neoID])
    }

    @Test("只有 MacBook Neo 路由要求会话临时主屏；一加、iPad、ThinkPad 都保持普通副屏")
    func onlyNeoClaimsMain() {
        let c = config()
        func main(_ name: String) -> [Bool] {
            ScreenPlan.wishes(config: c, remote: true, controllers: [name], trusted: true).map(\.main)
        }
        #expect(main(onePlusName) == [false])
        #expect(main(ipadName) == [false])
        #expect(main(thinkPadName) == [false])
        #expect(main(neoName) == [true])
        #expect(c.mainScreen == nil)
    }

    @Test("已绑定设备双向接管时，结果只跟当前控制端走")
    func takeoverBothWays() {
        #expect([selected([onePlusName]), selected([ipadName]), selected([onePlusName])] == [[onePlusID], [ipadID], [onePlusID]])
        #expect([selected([ipadName]), selected([onePlusName]), selected([ipadName])] == [[ipadID], [onePlusID], [ipadID]])
        #expect([selected([thinkPadName]), selected([onePlusName])] == [[thinkPadID], [onePlusID]])
        #expect([selected([onePlusName]), selected([thinkPadName])] == [[onePlusID], [thinkPadID]])
        #expect([selected([neoName]), selected([ipadName])] == [[neoID], [ipadID]])
        #expect([selected([thinkPadName]), selected([neoName])] == [[thinkPadID], [neoID]])
        #expect([selected([neoName]), selected([legionName])] == [[neoID], []])
        #expect([selected([neoName]), selected([onePlusName]), selected([thinkPadName])] == [[neoID], [onePlusID], [thinkPadID]])
        #expect([selected([ipadName]), selected([thinkPadName])] == [[ipadID], [thinkPadID]])
        #expect([selected([thinkPadName]), selected(["未绑定设备"])] == [[thinkPadID], []])
        let c = config()
        let neo = ScreenPlan.wishes(config: c, remote: true, controllers: [neoName], trusted: true)
        let onePlus = ScreenPlan.wishes(config: c, remote: true, controllers: [onePlusName], trusted: true)
        let ipad = ScreenPlan.wishes(config: c, remote: true, controllers: [ipadName], trusted: true)
        let thinkPad = ScreenPlan.wishes(config: c, remote: true, controllers: [thinkPadName], trusted: true)
        #expect([neo.map(\.main), onePlus.map(\.main), ipad.map(\.main), thinkPad.map(\.main)] == [[true], [false], [false], [false]])
    }

    @Test("未识别、未绑定、多个名称及其他设备都旁路")
    func defaultsToBypass() {
        #expect(selected([]).isEmpty)
        #expect(selected(["未绑定设备"]).isEmpty)
        #expect(selected([legionName]).isEmpty)
        #expect(config().binding(for: legionName)?.screen == nil)
        #expect(selected([onePlusName, ipadName]).isEmpty)
    }

    @Test("目标关闭或远程断开时不创建屏")
    func disabledOrDisconnected() {
        var c = config()
        c.screens[0].enabled = false
        #expect(selected([onePlusName], config: c).isEmpty)
        c.screens[0].enabled = true
        c.screens[1].enabled = false
        #expect(selected([ipadName], config: c).isEmpty)
        c.screens[1].enabled = true
        c.screens[2].enabled = false
        #expect(selected([thinkPadName], config: c).isEmpty)
        c.screens[2].enabled = true
        c.screens[3].enabled = false
        #expect(selected([neoName], config: c).isEmpty)
        c.screens[3].enabled = true
        c.removeScreen(neoID)
        #expect(selected([neoName], config: c).isEmpty)
        #expect(selected([onePlusName], remote: false, config: c).isEmpty)
        #expect(selected([ipadName], remote: false, config: c).isEmpty)
        #expect(selected([thinkPadName], remote: false, config: c).isEmpty)
        #expect(selected([neoName], remote: false, config: c).isEmpty)
    }

    @Test("手机屏与 iPad 屏都保持触屏行为")
    func touchBehavior() {
        let c = config()
        let onePlus = ScreenPlan.wishes(config: c, remote: true, controllers: [onePlusName], trusted: true)
        let ipad = ScreenPlan.wishes(config: c, remote: true, controllers: [ipadName], trusted: true)
        #expect(onePlus.map(\.behavior) == [.touchScreen])
        #expect(ipad.map(\.behavior) == [.touchScreen])
    }

    @Test("ThinkPad 只创建 1280×720 电脑屏，不带出手机或 iPad 屏")
    func thinkPadComputerBehavior() throws {
        let c = config()
        let wishes = ScreenPlan.wishes(config: c, remote: true, controllers: [thinkPadName], trusted: true)
        #expect(wishes.count == 1)
        let wish = try #require(wishes.first)
        #expect(wish.id == thinkPadID)
        #expect(wish.behavior == .computer)
        #expect(c.screens[2].orientation == .landscape)
        #expect(c.screens[2].device.screen == DeviceScreen(width: 720, height: 1280))
        #expect(wish.fit.baseWidth == 1280)
        #expect(wish.fit.size(width: wish.fit.baseWidth) == CGSize(width: 1280, height: 720))
    }

    @Test("Neo 只创建 1408×881 电脑屏，不带出其他设备屏")
    func neoComputerBehavior() throws {
        let c = config()
        let wishes = ScreenPlan.wishes(config: c, remote: true, controllers: [neoName], trusted: true)
        #expect(wishes.count == 1)
        let wish = try #require(wishes.first)
        #expect(wish.id == neoID)
        #expect(wish.behavior == .computer)
        #expect(c.screens[3].orientation == .landscape)
        #expect(c.screens[3].device.screen == DeviceScreen(width: 881, height: 1408))
        #expect(c.screens[3].device.screen.notch == nil)
        #expect(wish.fit.baseWidth == 1408)
        #expect(wish.fit.size(width: wish.fit.baseWidth) == CGSize(width: 1408, height: 881))
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
