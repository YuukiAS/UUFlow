# UUFlow Roadmap

UUFlow 是基于 [zephyr4123/snug](https://github.com/zephyr4123/snug) 继续发展的独立产品。上游提供了成熟的虚拟屏、窗口管理、移动端触控和远控适配基础；UUFlow 在此基础上继续解决多控制端专属屏、控制端识别、输入语义切换和远程电脑操作体验。

项目继续保留上游 MIT 许可、版权与必要的技术致谢，但从这一阶段开始，**用户看到的产品只叫 UUFlow**。

---

## 产品边界

UUFlow 最终由两部分组成。

### 被控 Mac：UUFlow

安装在 Mac mini / 其他被控 Mac 上，负责：

- 识别当前 UU远程 控制端；
- 为手机、平板、电脑按设备创建对应的专属虚拟屏；
- 按控制端决定创建专属屏或完全旁路；
- 手机、平板的触控、App 资源库和窗口适配；
- 电脑控制端的专属屏、临时主屏与显示恢复；
- 输出当前控制端的本地状态，作为键盘模式的唯一识别来源。

### 电脑控制端：UUFlow Controller

安装在 MacBook / Windows 电脑控制端，只负责本机与远端输入路由：

- LOCAL：快捷键和手势作用于控制端本机；
- REMOTE：选定快捷键和后续手势只作用于远程 Mac；
- 不复制虚拟屏、窗口管理或远控传输；
- 不修改 UU远程 本体。

手机、iPad、Android 平板只使用 UU远程，不安装 Controller。

远程画面和键鼠传输始终由 UU远程 负责；UUFlow 不自建远控协议。

---

## 品牌、兼容与上游边界

### 用户可见名称

后续用户可见内容统一使用 **UUFlow**：

- App 名称；
- 菜单栏、窗口标题、关于页、欢迎页和设置；
- 安装路径和安装包文件名；
- README、ROADMAP 和用户文档；
- 面向用户的状态、错误和日志说明；
- 后续 Controller 名称。

不再在用户界面和普通文档中继续使用 Snug 作为产品名。

### 内部兼容

为降低无价值改名风险，第一轮产品化不机械重命名所有内部源码符号。

可以暂时保留：

- SnugCore、SnugSystem 等内部 Swift target / type；
- 已存在的数据目录或 bundle identity；
- 为兼容旧安装、辅助功能授权、配置与还原记录所需的内部路径。

这些属于实现细节，不应继续暴露给普通用户。

### 上游同步

UUFlow 继续把 zephyr4123/snug 视为上游来源：

- 上游 bug fix 和通用能力继续评估同步；
- UUFlow 自己新增的控制端路由、临时主屏、物理屏恢复、键盘状态源和 Controller 保持独立；
- 不为了方便同步而牺牲已经验证过的 UUFlow 行为；
- 每次同步上游必须通过 UUFlow 自己的完整回归。

---

# Phase 1：设备专属屏与自动路由

**状态：功能完成并通过真实设备验证；等待当前本地 feature branch 正式整合进主线后冻结。**

目标是让不同控制端连接同一台 Mac mini 时，自动得到适合自己的屏幕；不需要增强显示的设备保持原有 UU远程 体验。

## 路由原则

UUFlow 复用现有“本机被控中”控制端读取，根据 UU 实际报告的控制端名称决定：

- 绑定到某块屏：只创建对应专属屏；
- 绑定为旁路：不创建 UUFlow 虚拟屏；
- 未识别、未绑定、冲突或目标屏不可用：默认旁路。

不再采用“只要远程中就创建全部 enabled 屏”的旧行为。

## 已完成设备

### 一加 12

- 实际 UU 名称：一加 12 全网通版
- 专属横屏；
- 自动路由完成；
- 手机触控与移动端行为沿用现有能力。

### iPad Air M1

- 实际 UU 名称：iPad Air 5
- iPad Air 第 5 代 / M1；
- 专属平板横屏；
- 自动路由完成。

### ThinkPad E16

- 实际 UU 名称：THINKPAD-E16
- 专属电脑屏；
- 最终冻结逻辑分辨率：**1280×720**
- 1280×800 已经因 UU 实际画布比例导致明显黑边而淘汰；
- 自动路由完成；
- computer 行为，不做手机/平板触控翻译。

### MacBook Neo

- 实际 UU 名称：MacBook-Neo
- 专属电脑屏：**1408×881**
- 自动路由完成；
- 会话期间启用 mainDuringSession：
  - Neo 专属屏创建后临时成为 Mac mini 主屏；
  - Dock、主工作区和窗口随 macOS 进入 Neo 屏；
  - Neo 断开或换手时先恢复 Dell 主屏与原排列，再撤 Neo 屏；
  - AppConfig.mainScreen 仍为空，不形成常驻虚拟主屏。

### Legion Y9000P

- 实际 UU 名称：LEGION-Y9000P
- 显式旁路；
- 不创建 UUFlow 虚拟屏；
- 不改变 Mac mini 显示拓扑。

## Dell 物理屏保护

Mac mini 当前 Dell 基线：

- 型号：DELL S2725QS
- 逻辑分辨率：1920×1080 HiDPI
- backing：3840×2160
- 刷新率：120Hz
- BetterDisplay mode：115

Phase 1 已经修复物理屏模式错误永久写回的问题。

长期不变量：

> UUFlow 创建、切换、设主屏和撤除虚拟屏，不得把远控期间出现的临时物理屏模式保存成新的长期基线。

## Phase 1 收口条件

在正式整合当前本地 feature branch 时再次确认：

- 一加、iPad、ThinkPad、Neo 四类专属屏路由均保留；
- Legion 显式旁路；
- 未识别设备默认旁路；
- Neo mainDuringSession 正常；
- Dell 恢复逻辑正常；
- 完整 scripts/snug check 通过；
- 当前已验证实现全部进入主线后，将本阶段标为 **DONE / FROZEN**。

---

# Phase 2：UUFlow 产品化与单一控制端状态源

这是 Phase 1 收口后的下一阶段。

本阶段先完成产品身份和状态源统一，再进入 LOCAL / REMOTE Controller。目标是把现在分散在 UUFlow 与 Local Compute 的“当前控制端是谁”收敛成一个事实源。

## 步骤 1：产品正式改名为 UUFlow

用户可见产品全面改名：

- App：UUFlow.app
- About / Settings / Welcome / 状态栏：UUFlow
- README / 用户文档：UUFlow
- 安装包、窗口标题和面向用户的提示：UUFlow
- GitHub 仓库继续使用 YuukiAS/UUFlow

内部 Swift target、兼容路径和 bundle identity 暂不做无功能价值的大规模重命名。

### 迁移要求

改名不得造成：

- 现有配置丢失；
- 屏幕身份变化；
- 辅助功能权限无必要失效；
- 还原账丢失；
- 新增一套平行 Application Support 数据目录。

如果 App 文件名从 Snug.app 改为 UUFlow.app 会影响已有授权或安装替换流程，必须先设计一次性迁移和回滚，再切换；不能靠用户反复重新授权来证明改名成功。

## 步骤 2：移除上游运行时自动更新

当前 fork 已经有独立功能，不能再把 zephyr4123/snug 的 release 当成 UUFlow 的可安装“新版本”。

因此正式移除运行时：

- 启动自动检查；
- “检查更新”设置；
- 更新源选择；
- 新版本弹窗；
- 指向上游 zephyr4123/snug 和 dl.zephyrxiang.com/snug 的 update feed；
- 任何会把当前 UUFlow 自动替换成上游 Snug build 的路径。

保留开发阶段真正需要的：

- build；
- check；
- install；
- 本地打包能力。

公开发布 UUFlow 之前，再单独设计 UUFlow 自己的 release / update source；本阶段不为未来发布提前造第二套更新系统。

## 步骤 3：UUFlow 成为唯一控制端状态源

现状存在两套识别：

1. UUFlow 为了设备路由读取当前控制端；
2. Local Compute 的 UUReadState.swift 另外读取 UU executable 固定 offset、解密 plist、读取 Cache.db 并调用私有接口，只为了再次判断 Windows/macOS。

第二套链路已经因为 UU 更新移动二进制常量而真实失效过。

最终应改成：

    UU远程
      ↓
    UUFlow 已有控制端读取
      ↓
    控制端名称 + 平台 / 显式设备绑定
      ↓
    UUFlow 本地状态
      ↓
    Local Compute auto.py
      ↓
    Karabiner windows / mac / off

### 平台来源优先级

优先复用已有能力：

1. 当前 UU 辅助功能树中若存在可靠的平台信息，直接读取；
2. 如当前 UI 已不暴露平台，则复用 Phase 1 已确认的控制端名称绑定，在设备配置中显式声明键盘语义；
3. 不再引入新的 UU binary/private API 识别链。

禁止根据设备名称字符串猜平台。

### 最小本地状态合同

UUFlow 输出无敏感数据的本地状态，至少表达：

- schema version；
- remote 是否为 UU；
- 当前是否存在有效控制端；
- controller name；
- controller platform（如可可靠取得）；
- keyboard mode：windows | mac | off；
- observation timestamp。

必须保证：

- 状态变化及时更新；
- 活跃时有低频新鲜度证明；
- UUFlow 退出、崩溃、辅助功能读取失败、控制端不明确、手机/平板控制或状态过期 → off；
- 不输出 token、device ID、UU 账号、请求头或其他敏感信息。

## 步骤 4：Local Compute 影子消费，再切生产

跨仓库职责：

### UUFlow

负责：

- UU 控制端识别；
- 平台 / 显式键盘语义映射；
- 本地状态输出；
- 自己的打包、安装和回归。

### Local_Compute_Infrastructure

负责：

- 读取 UUFlow 状态合同；
- windows / mac / off 三态；
- Karabiner 的 uu_remote_active、fallback 与切换顺序；
- Mac mini 机器级安装、回滚和验证记录。

迁移顺序必须是：

1. 先部署 UUFlow 状态 producer；
2. 在 ThinkPad 当前真实会话证明 windows；
3. 在 Neo 真实会话证明 mac；
4. Local Compute 候选读取 UUFlow 状态；
5. 离线与临时验证全部通过；
6. 原子切换 Local consumer；
7. ThinkPad 真人最小验证 Ctrl+A/C/V；
8. Neo 路径确认不会套 Windows 语义；
9. 再退役旧 binary reader。

任一时刻至少保留一条健康识别链。

## 步骤 5：退役旧 UU 二进制 reader

只有新链路真实生产通过后，才从 active runtime 删除：

- UUReadState.swift
- uu-read-state
- 固定二进制 offset
- UU executable 常量读取
- plist 解密
- Cache.db / 私有平台查询链中只服务于旧平台识别的活动代码
- 对应构建与部署逻辑

历史报告保留，明确标注为 retired implementation。

完成后，UU 普通升级不应再因为二进制位置变化单独导致 Ctrl 整族失效。

## Phase 2 完成标准

- 用户可见产品名全部为 UUFlow；
- 上游运行时更新入口完全退出产品；
- UUFlow 是唯一控制端状态源；
- ThinkPad → windows；
- Neo → mac；
- 手机/平板/未知/过期 → off；
- Local Compute 只消费 UUFlow 状态；
- 旧 binary reader 已从 active runtime 退役；
- ThinkPad Ctrl+A/C/V 真人通过；
- Phase 1 屏幕路由和 Dell 恢复没有回归。

---

# Phase 3：MacBook Neo LOCAL / REMOTE 键盘模式

Phase 2 完成后开始。

目标设备：MacBook Neo。

第一版只做键盘，不做触控板。

## 行为

### LOCAL

- 快捷键作用于 Neo 本机；
- 不影响 macOS 原有操作。

### REMOTE

- 选定快捷键只作用于远程 Mac mini；
- Neo 本机不能同时消费同一次快捷键。

### 安全恢复

以下情况自动回到 LOCAL：

- UU远程 不在前台；
- 远程会话结束；
- Controller 退出；
- Controller 异常；
- 当前远端状态无法可靠确认。

## 第一项技术门槛：Alt+Tab

先只验证：

> REMOTE 模式下能否阻止 Neo 本机消费 Alt+Tab，并让同一组合稳定到达 Mac mini，由 Mac mini 上现有 AltTab 处理。

通过后再做：

- 固定 LOCAL / REMOTE 切换快捷键；
- 轻量状态提示；
- 快速回到 LOCAL；
- 不修改 UU远程 本体；
- 不先做复杂配置界面。

不把“自动选择 UU 显示标签”列为本阶段目标；当前设备专属屏已可正常使用，不为非必要体验继续扩张。

---

# Phase 4：Windows LOCAL / REMOTE 键盘模式

Phase 3 稳定后，把同一行为模型带到 ThinkPad / Legion。

目标：

- LOCAL：快捷键作用于 Windows 本机；
- REMOTE：选定快捷键只作用于远程 Mac；
- 会话结束、Controller 退出或异常时恢复 LOCAL。

复用 Phase 3 的模式语义、状态提示和恢复规则。

Windows 底层按自己的稳定机制实现，不为了跨平台统一代码引入重量级框架。

实际验证前不假设 Alt、Win、Ctrl 到远端 macOS 修饰键的最终组合。

---

# Phase 5：macOS 触控板远端手势

只有 Phase 3 键盘模式稳定后开始。

第一批目标：

- 三指左右 → 远程 Mac Space；
- 三指上 → 远程 Mission Control；
- 三指下 → 远程 App Exposé。

LOCAL 下保持 Neo 本机 macOS 手势。

REMOTE 下同一手势只作用于远程 Mac，本机不能同时执行。

先做独立技术验证。若公开接口只能观察、不能可靠阻止本机动作，再单独评估更底层实现；实验性路径不得直接进入日常版本。

---

# Phase 6：Windows 触控板与后续增强

只有 macOS 触控板方案证明实际价值后，再评估 Windows Precision Touchpad。

重点确认：

- 能否区分三/四指系统手势；
- REMOTE 能否阻止 Windows 本机动作；
- 能否稳定转成远程 Mac 系统操作；
- Controller 异常退出后能否可靠恢复。

无法稳定满足时，Windows 保留键盘 Controller，不为了功能对称引入脆弱实现。

---

## 两个仓库的长期职责

### YuukiAS/UUFlow

产品与远控行为的事实来源：

- 控制端识别；
- 专属屏和路由；
- 移动端触控；
- 电脑屏与临时主屏；
- 控制端键盘语义状态；
- Controller 产品。

### YuukiAS/Local_Compute_Infrastructure

机器配置与部署事实来源：

- Mac mini / Neo / ThinkPad / Legion 的安装状态；
- Karabiner 配置；
- UUFlow 本地状态消费合同；
- 系统级启动、回滚与验收；
- BetterDisplay 等机器环境基线。

Local Compute 不再复制 UUFlow 的控制端识别实现。

---

## 当前实施顺序

1. **整合并冻结 Phase 1 当前本地实现**，确保全部真实验证提交进入主线。
2. **Phase 2 / 产品化**：用户可见名称统一为 UUFlow。
3. **Phase 2 / 更新收口**：移除上游 Snug 运行时更新检查和更新 UI。
4. **Phase 2 / 状态源统一**：UUFlow 输出控制端键盘语义状态。
5. **Phase 2 / 双仓迁移**：Local Compute 影子消费 → 真实验证 → 切生产 → 删除旧 binary reader。
6. **Phase 3**：MacBook Neo LOCAL / REMOTE + Alt+Tab。
7. **Phase 4**：Windows LOCAL / REMOTE。
8. **Phase 5**：MacBook Neo 触控板远端手势。
9. **Phase 6**：Windows 触控板与后续增强。

每一阶段通过自己的真实验收后再进入下一阶段；不为了“顺手”把未来阶段提前塞进当前实现。
