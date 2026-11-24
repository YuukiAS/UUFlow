# UUFlow Roadmap

UUFlow 基于 [zephyr4123/snug](https://github.com/zephyr4123/snug) 的 MIT 许可代码继续开发。上游已经解决被控 Mac 上的虚拟屏、窗口管理、UU远程 会话识别、手机/平板触控和 App 资源库；UUFlow 在此基础上补齐“不同控制端得到不同远控体验”和电脑控制端的本机 / 远端输入切换。

## 产品边界

最终形态分三端：

- **Mac mini / 被控 Mac**：安装 UUFlow 主体。负责虚拟屏、窗口管理、UU 会话与控制端识别、手机/平板触控增强，以及按控制端选择对应屏幕或旁路。
- **macOS 电脑控制端**：安装轻量 Controller。负责本机 / 远端输入模式，让同一套快捷键和后续触控板手势按需作用于控制端本机或远程 Mac。
- **Windows 电脑控制端**：安装轻量 Controller，职责与 macOS Controller 相同。
- **手机 / iPad / Android 平板**：只安装 UU远程，不安装 Controller；由 Mac mini 上的 UUFlow 提供专属虚拟屏、触控和 App 资源库。

UUFlow 不复制 UU远程 的传输协议。远程画面与键鼠传输继续由 UU远程负责。

---

## Phase 1：设备专属屏与自动路由

目标是让不同控制端连接同一台 Mac mini 时得到各自合适的屏幕；不需要增强显示的设备保持原来的 UU远程 体验。

### 路由规则

UUFlow 复用现有“本机被控中”控制端读取能力，根据 UU 实际报告的控制端名称决定：

- 绑定到某块屏：只创建该屏；
- 配置为旁路：不创建 UUFlow 虚拟屏；
- 名称未识别、未绑定、映射冲突或目标屏不可用：默认旁路。

屏幕选择只由这一套路由决定，不再因为“远程中”就创建所有 enabled 屏。控制端名称到屏幕的判断集中在屏幕策略层，不再新增第二套设备识别或会话状态机。

### 当前设备

- **一加 12**：专属横屏已配置并完成自动路由。UU 实际名称为“一加 12 全网通版”。
- **iPad Air M1**：按 iPad Air 第 5 代配置横屏，1640×2360、points 820；自动路由已完成。UU 实际名称为“iPad Air 5”。
- **MacBook Neo**：电脑横屏已经准备，自定义逻辑分辨率 1408×881、无刘海。自动路由明天处理，本轮保持未动。
- **ThinkPad E16**：专属电脑横屏已按自定义逻辑分辨率 **1280×800** 配置并完成自动路由，UU 实际名称为“THINKPAD-E16”。该尺寸与 Windows 200% 缩放的逻辑工作区一致，2 倍模式正好对应 2560×1600；Snug 仍可提供更宽档位，需要更多工作区时可再调高。Windows 当前 225% 只作为本机文字大小偏好的参考，不把 1138×711 这种非整数缩放结果写成固定虚拟屏规格。
- **Legion Y9000P**：保持旁路，不创建 UUFlow 虚拟屏，不改变 Mac mini 显示拓扑。

### Phase 1 完成标准

1. 一加连接时只出现一加屏；
2. iPad 连接时只出现 iPad 屏；
3. Neo 连接时只出现 Neo 电脑屏；
4. ThinkPad 连接时只出现 ThinkPad 电脑屏；
5. Legion 连接时保持旁路；
6. 未识别或未绑定设备保持旁路；
7. 设备接管时旧屏撤掉、新设备对应屏按路由建立；
8. 断开后窗口和显示器按现有 Snug 机制恢复；
9. 手机、平板继续使用触控增强；电脑屏保持普通显示器行为；
10. `mainScreen` 默认保持为空，不依赖常驻虚拟主屏实现路由。

当前一加、iPad 与 ThinkPad 的自动路由已经在本地 feature branch `codex/controller-screen-routing-phase-0-5` 完成；MacBook Neo 明天处理，Legion 继续保持旁路目标。该分支尚未合并、未 push；Phase 2 的 macOS 本机 / 远端键盘模式尚未开始。

---

## Phase 2：macOS 本机 / 远端键盘模式

目标设备首先是 MacBook Neo。

第一步只解决键盘，不做触控板。核心行为：

- **本机模式**：快捷键继续作用于 MacBook Neo 本机；
- **远端模式**：选定快捷键只作用于远程 Mac mini；
- 模式切换不能让同一次按键同时作用于两端；
- UU远程 不在前台、远程会话结束、Controller 退出或异常时，恢复安全的本机输入状态。

### 第一项技术验证：Alt+Tab

先只验证一件事：

> UU远程 前台时，Controller 能否在远端模式阻止 Neo 本机消费 `Alt+Tab`，并让同一组合稳定到达 Mac mini，由 Mac mini 上现有的 AltTab 处理。

通过后做最小可用版：

- 一个固定的本机 / 远端切换快捷键；
- 轻量、明确的当前模式提示；
- 可以快速回到本机模式；
- 不修改 UU远程 本体；
- 不先做复杂设置界面。

其他快捷键等真实使用证明需要后再加。

---

## Phase 3：Windows 本机 / 远端键盘模式

macOS 键盘模式稳定后，把同一行为带到 ThinkPad / Windows 控制端。

目标保持一致：

- **本机模式**：系统快捷键作用于 Windows 本机；
- **远端模式**：选定快捷键不再触发 Windows 本机动作，而是经 UU远程作用于 Mac mini；
- 会话结束、Controller 退出或异常时恢复本机输入。

复用 Phase 2 已经确定的状态模型、切换语义和恢复规则；Windows 底层按自己的稳定机制实现，不为了代码统一引入重量级跨平台框架。

在真实链路验证前，不预设 Windows 的 `Alt`、`Win`、`Ctrl` 到远端 macOS 修饰键的最终映射。

---

## Phase 4：macOS 触控板远端手势

键盘本机 / 远端模式稳定后，再处理 MacBook Neo 触控板。

第一批目标：

- 三指左右：切换远程 Mac 的 Space；
- 三指上：远程 Mission Control；
- 三指下：远程 App Exposé。

本机模式保持 macOS 原有手势；远端模式下，同一手势只作用于远程 Mac，不能同时触发 Neo 本机的 Space 或 Mission Control。

先做独立技术验证。优先使用稳定接口；如果只能观察手势、不能可靠阻止本机动作，再单独评估更底层方案，不把实验实现直接并入日常版本。

---

## Phase 5：Windows 触控板与后续输入增强

只有 macOS 触控板方案已经证明有实际价值后，再评估 Windows Precision Touchpad。

需要确认 Windows 能否稳定：

- 区分三/四指系统手势；
- 在远端模式阻止本机动作；
- 将动作转换成远程 Mac 系统操作；
- Controller 异常退出后可靠恢复。

若这些条件不能稳定满足，Windows 保留键盘 Controller，不为了平台功能对称引入脆弱实现。

---

## 上游同步原则

UUFlow 是 Snug 的功能扩展，不以大规模重写上游为目标。

长期原则：

- 尽量保留 Snug 的核心目录结构和成熟实现；
- 被控端已有功能优先直接复用；
- 新增能力优先补真实缺口，不重复实现已有模块；
- Controller 放在独立目录 / target，减少与上游同步冲突；
- 上游重要修复继续评估并同步；
- 修改 Snug 原有行为时必须有明确的 UUFlow 用户价值；
- 保留原项目版权与 MIT 许可要求。

---

## 当前实施顺序

1. **完成 Phase 1**：一加、iPad 和 ThinkPad 已完成；MacBook Neo 明天处理，Legion 继续保持旁路目标。
2. **Phase 2**：MacBook Neo 上实现本机 / 远端键盘模式，第一项只打通 Alt+Tab。
3. **Phase 3**：把同一键盘模式带到 ThinkPad / Windows。
4. **Phase 4**：MacBook Neo 三指 Space / Mission Control / App Exposé。
5. **Phase 5**：最后评估 Windows 触控板与其他输入增强。

Phase 1 没有收口前，不开始 Controller 和触控板开发。
