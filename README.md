# UUFlow

UUFlow 是面向 UU远程 的 macOS 显示增强工具。它会根据当前真实控制端，只创建一块与该设备匹配的虚拟屏，并在会话结束后恢复窗口、主屏和物理显示模式。

> UUFlow 不是 UU远程 官方软件。目前没有公开的 UUFlow 二进制 Release；请从源码构建和安装。

[English](README.en.md) · [日本語](README.ja.md) · [开发文档](docs/development.md) · [工作原理](docs/how-it-works.md)

## 当前能力

Phase 1 已完成并冻结：

- 一加 12（`一加 12 全网通版`）只创建一加专属横屏；
- iPad Air M1（`iPad Air 5`）只创建 iPad 专属屏；
- ThinkPad E16（`THINKPAD-E16`）只创建 `1280×720` 电脑屏；
- MacBook Neo（`MacBook-Neo`）只创建 `1408×881` 电脑屏，并在会话期间临时成为主屏；
- Legion Y9000P（`LEGION-Y9000P`）显式旁路，不改变显示拓扑；
- 未识别、未绑定、名称冲突或目标不可用时默认旁路；
- 手机和平板沿用触控手势与 App 资源库，电脑屏保持普通桌面行为；
- Neo 断开或换手时先恢复原物理主屏，再撤虚拟屏；
- 创建、撤除虚拟屏时保护物理显示器原有分辨率、HiDPI 与刷新率。

控制端 keyboard mode、LOCAL / REMOTE、Alt+Tab 和触控板尚未实现，不属于当前版本能力。

## 安装

需要 macOS 14 或更新版本、Xcode/Swift 6，以及已经安装并可用的 UU远程。

```bash
git clone https://github.com/YuukiAS/UUFlow.git
cd UUFlow
scripts/uuflow check
scripts/uuflow install
```

安装完成后，App 位于 `/Applications/UUFlow.app`。首次使用需要 macOS“辅助功能”权限，用于读取 UU远程 的当前控制端、移动窗口和转换触控操作。

## 开发命令

```text
scripts/uuflow check             完整构建与测试门禁
scripts/uuflow app               构建 build/UUFlow.app
scripts/uuflow install           安全安装并打开 /Applications/UUFlow.app
scripts/uuflow dist              生成本地签名、公证的 UUFlow DMG
scripts/uuflow remote-check uu   UU远程 兼容自检
```

Swift 的内部 target 仍使用 `Snug`、`SnugCore` 和 `SnugSystem`，bundle ID 仍为 `com.zephyr4123.snug`，配置和还原记录仍从 `~/Library/Application Support/Snug` 读取。这些兼容名称用于保留现有授权、屏幕身份和用户数据，不是产品品牌。

## 数据与隐私

UUFlow 在本机读取 UU远程 的可访问性界面和日志，用于识别当前控制端与推流屏幕。App 不包含运行时自动更新，不会在启动时访问上游 update feed，也不会自动下载或替换 App。

## 上游与许可

UUFlow 基于 [Snug](https://github.com/zephyr4123/snug) 与更早的 [UUyc-companion](https://github.com/aoyamashou/UUyc-companion) 发展，沿用 MIT 许可。原作者版权、第三方归属和完整条款见 [LICENSE](LICENSE)。
