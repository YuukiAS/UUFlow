# UUFlow Roadmap

UUFlow 基于 [zephyr4123/snug](https://github.com/zephyr4123/snug) 的 MIT 许可代码继续开发。上游已经解决 UU远程 被控 Mac 上的虚拟屏、窗口管理、手机/平板触控和 App 资源库；UUFlow 的新增目标是把电脑控制端也做成更接近本机的操作体验。

## 产品边界

最终形态分为三层：

- **Mac mini / 被控 Mac**：安装 UUFlow 主体。负责 Snug 已有的虚拟屏、窗口管理、UU 会话识别、手机和平板触控增强，以及以后需要的被控端能力。
- **MacBook / macOS 控制端**：安装轻量 Controller。只负责 LOCAL / REMOTE 输入路由，让同一套快捷键和后续触控板手势按需作用于本机或远程 Mac。
- **Windows 控制端**：安装轻量 Controller，职责与 macOS Controller 相同。
- **手机 / iPad / Android 平板**：只安装 UU远程，不安装 UUFlow Controller。继续使用 UUFlow 主体提供的专属虚拟屏、触控和 App 资源库。

Controller 不复制 Snug 的虚拟屏和窗口管理能力，也不自建远控协议；远程画面、键鼠传输仍由 UU远程负责。

---

## Phase 0：先部署现有 fork，确认 Snug 基线值不值得保留

这一阶段不开发 Controller，也不改触控板。

在 Mac mini 上直接用当前 UUFlow fork：

1. 跑完整现有构建与测试，确认 fork 基线健康。
2. 构建并安装当前 App。
3. 授予现有功能真正需要的权限，不提前申请后续 Controller 权限。
4. 建立至少以下几块测试屏：
   - MacBook Neo；
   - ThinkPad；
   - 手机；
   - iPad / 平板。
5. 用真实 UU远程分别测试：
   - Neo / ThinkPad 画面是否铺满、比例和字号是否明显优于直接远控主屏；
   - 多屏切换是否稳定；
   - App 资源库能否把别的屏幕上的窗口拉到当前远程屏，并正确还原；
   - 手机和平板的单指滚动、长按右键、拖选文字是否符合预期；
   - 断线、重连、退出 UUFlow 后窗口和显示器是否恢复正常。

本阶段的目标是回答一个问题：

> 上游 Snug 的显示、窗口和移动端触控能力是否值得作为 UUFlow 的长期底座？

如果通过，这部分尽量少改，后续优先保持与上游可同步。

---

## Phase 1：macOS Controller，先解决键盘 LOCAL / REMOTE

第一项新增能力只做键盘，不做触控板。

目标设备：MacBook Neo 等 macOS 控制端。

### 第一项技术验证

先只验证一件事：

> UU远程 前台时，macOS Controller 能否在 REMOTE 模式阻止本机消费 `Alt+Tab`，并让同一组合稳定到达远程 Mac，由远程 Mac 上现有的 AltTab 处理。

需要分别确认：

- LOCAL 模式：`Alt+Tab` 继续切换 MacBook 本机 App；
- REMOTE 模式：MacBook 本机不切 App，远程 Mac mini 收到完整按键并执行远端 AltTab；
- 切换过程中不会出现一次同时作用于本机和远端；
- Controller 退出或异常时立即恢复系统原有输入行为。

### 第一版 Controller

技术验证通过后，再做最小可用版：

- 一个固定的 LOCAL / REMOTE 切换快捷键；
- 当前模式有轻量、明确的状态提示；
- 可以快速临时退出 REMOTE；
- UU远程 不在前台或远程会话结束时，优先恢复安全的本机输入状态；
- 不改 UU远程 设置，不依赖修改 UU 本体；
- 不加入复杂配置界面。

第一版先覆盖 `Alt+Tab`。其他键盘组合只有在真实使用中证明需要时再增加。

---

## Phase 2：Windows Controller，复用同一行为模型

macOS 键盘模式稳定后，再做 ThinkPad / Windows 控制端。

目标保持一致：

- LOCAL：系统快捷键作用于 Windows 本机；
- REMOTE：选定快捷键不再触发 Windows 本机动作，而是经 UU远程作用于远程 Mac。

优先复用 Phase 1 已经确定的：

- LOCAL / REMOTE 状态模型；
- 切换快捷键的语义；
- 状态提示；
- 会话结束后的恢复规则；
- 异常退出时的输入恢复规则。

Windows 可以使用自己的底层键盘机制实现，不为了“跨平台统一代码”强行引入重量级框架。

在真实链路确认前，不假设 Windows 的 `Alt`、`Win`、`Ctrl` 与远端 macOS 修饰键如何映射；以 ThinkPad → UU远程 → Mac mini 实测决定。

---

## Phase 3：macOS 触控板远端手势

键盘 LOCAL / REMOTE 已经稳定以后，再开始最难的一层。

第一批目标手势：

- 三指左右：切换远程 Mac 的 Space；
- 三指上：远程 Mission Control；
- 三指下：远程 App Exposé；
- 是否加入四指左右切 App，等前三项实际体验后决定。

核心验收标准不是“能识别手势”，而是：

### LOCAL

macOS 本机手势保持原样。

### REMOTE

同一手势只作用于远程 Mac，本机不能同时切 Space 或打开 Mission Control。

先做独立技术验证，再决定正式实现。优先使用稳定公开接口；如果公开接口只能观察、不能可靠阻止本机动作，再单独评估更底层方案，不把实验性实现直接并入日常版本。

---

## Phase 4：Windows 触控板与后续输入增强

只有 macOS 触控板方案证明产品价值后，再评估 Windows Precision Touchpad。

这一阶段不承诺与 macOS 完全同等能力。先调查 Windows 能否稳定：

- 区分三/四指系统手势；
- 在 REMOTE 模式阻止本机动作；
- 将动作转换成远程 Mac 的系统操作；
- 在 Controller 异常退出后可靠恢复。

无法稳定满足这些条件时，Windows 继续保留键盘 Controller，不为了功能对称引入脆弱实现。

---

## 上游同步原则

UUFlow 是 Snug 的功能扩展，不以大规模重写上游为目标。

长期原则：

- 尽量保留 Snug 的核心目录结构和成熟实现；
- 被控端已有功能优先直接复用；
- Controller 放在清晰独立的目录/目标中，减少与上游冲突；
- 上游的重要修复继续评估并同步；
- 修改 Snug 原有行为时，需要有 UUFlow 的明确用户价值；
- 保留原项目版权与 MIT 许可要求，并在文档中明确上游来源。

---

## 当前实施顺序

1. **部署当前 UUFlow fork 到 Mac mini，先看现有 Snug 能力实际效果。**
2. **macOS Controller：先打通 LOCAL / REMOTE + AltTab。**
3. **Windows Controller：把同一键盘模式带到 ThinkPad。**
4. **macOS 触控板：三指 Space / Mission Control / App Exposé。**
5. **最后再评估 Windows 触控板和其他输入增强。**

在 Phase 0 和 Phase 1 没有得到真实设备结果前，不提前建设后续阶段。
