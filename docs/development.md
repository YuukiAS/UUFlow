# 开发

## 日常入口

构建、测试、安装与本地打包统一使用 `scripts/uuflow`。

| 命令 | 作用 |
| :--- | :--- |
| `scripts/uuflow check` | 检查远控适配层边界，构建全部目标，运行全部 Swift 与 Python 测试 |
| `scripts/uuflow app` | 生成并签名通用二进制 `build/UUFlow.app` |
| `scripts/uuflow install` | 构建后安全迁移至 `/Applications/UUFlow.app`，确认新进程启动后才移除旧 `/Applications/Snug.app` |
| `scripts/uuflow dist` | 使用 Developer ID 与公证配置生成 `dist/<版本>/UUFlow-<版本>.dmg` |
| `scripts/uuflow remote-check uu [小时]` | UU远程 兼容自检，默认回看 4 小时，最多 72 小时 |

环境要求为 Xcode 与 Swift 6。版本号唯一来源是仓库根目录 `VERSION`。

需要把构建缓存放到外置盘时，在不提交的 `.machine.env` 中设置 `UUFLOW_BUILD_ROOT`。脚本会把 `.build` 和 `build` 迁到该目录，源码目录只保留符号链接；示例见 `.machine.env.example`。

钥匙串中有唯一一张 Developer ID Application 证书时自动使用；否则采用 ad-hoc 签名。可在不提交的 `.machine.env` 中设置：

```text
MAC_SIGNING_IDENTITY=<证书 SHA-1 或名称；- 表示 ad-hoc>
MAC_NOTARY_PROFILE=<notarytool 钥匙串档案名>
```

ad-hoc 签名的 designated requirement 会随构建变化。App 从 `Snug.app` 改名迁移到 `UUFlow.app` 时，即使 bundle ID 不变，macOS 也可能保留一条表面已开启但实际失效的辅助功能记录；此时删除旧条目、重新加入 `/Applications/UUFlow.app` 一次即可。使用稳定的 Developer ID 签名时不应依赖这条 ad-hoc 迁移路径。

当前仓库没有公开的 UUFlow Release，也没有运行时自动更新。`dist` 只产出本地 DMG，不上传、不生成 update feed。

## 产品名与兼容身份

用户可见产品名、App bundle 文件名、可执行文件名和 canonical CLI 都是 `UUFlow`。以下名称暂时保留为内部兼容实现：

- Swift package/target：`Snug`、`SnugCore`、`SnugSystem`；
- bundle ID：`com.zephyr4123.snug`；
- 数据目录：`~/Library/Application Support/Snug`；
- 日志：`~/Library/Logs/Snug.log`。

这些名称保护现有辅助功能授权、登录项、屏幕身份、配置和还原账。不要在没有迁移方案时改动。

旧配置中的 `updateSource` 会被解码器忽略，新版本不再写回。以 `Snug ` 开头的旧屏幕显示名会迁移为 `UUFlow `，screen ID、serial、route 和 restore record 不变。

## 代码结构

| 目标 | 内容 |
| :--- | :--- |
| `SnugCore` | 纯逻辑：远控端口与会话、路由计划、显示调度、机型、触控状态机、配置与持久化 |
| `SnugSystem` | 系统能力：虚拟屏、显示模式、主屏与排列、窗口、辅助功能、事件监听和截图 |
| `RemoteUU` | UU远程 信号、会话判定与日志解析的纯逻辑 |
| `RemoteUUSystem` | UU远程 的进程、界面、日志与诊断系统实现 |
| `Snug` | UUFlow App 层：控制器、设置、菜单栏、欢迎页、About 和屏上界面 |

依赖保持单向：核心不认识具体远控；只有 `Sources/Snug/App/Remotes.swift` 登记适配器。`scripts/uuflow check` 会验证边界、测试目标与目录、适配器登记及契约驱动。

## 远控与屏幕计划

`AppController` 每拍采样远控，经 `RemoteSession` 得出当前控制端，再由 `ScreenPlan.wishes` 生成计划：

- 真实远程只接受恰好一个控制端名称及其显式 route；
- 未识别、未绑定、冲突、目标缺失或 disabled 时返回空计划；
- Neo route 的 `mainDuringSession` 只影响当前会话，不写入 `AppConfig.mainScreen`；
- preview 模式仅供开发，会创建全部 enabled 屏，不能用于实机路由验收。

`ScreenSet` 是显示拓扑的唯一写入者；撤临时主屏时先恢复原主屏与排列，再撤虚拟屏。物理显示模式 A 在拓扑变化期间即使短暂变为 B，结束后也必须恢复 A，不能把 B 写成永久基线。

具体实现见 [工作原理](how-it-works.md)，新增远控见 [接入远控](remotes/README.md)。

## 启动参数

| 参数 | 作用 |
| :--- | :--- |
| `--render-<界面> <目录>` | 渲染 `settings` / `welcome` / `about` / `legacy` / `menu` / `screens` / `library`，不启动监控 |
| `--preview-screens` | 不等远程创建 enabled 屏；会真实改变显示拓扑 |
| `--dump-remote <远控>` | 打印该远控的原始信号、控制端与屏幕 |
| `--check-remote <远控> [小时]` | 输出兼容性报告 |
| `--probe-screens <规格…>` | 创建实验虚拟屏；会真实改变显示拓扑 |
| `--set-mode ...` / `--restore-mode ...` | App 内部显示模式帮助进程入口 |

## 数据与日志

| 位置 | 内容 |
| :--- | :--- |
| `~/Library/Application Support/Snug/config.json` | 屏幕、精确控制端 routes、触控设置与兼容字段 |
| `~/Library/Application Support/Snug/placed/` | 各屏窗口还原记录 |
| `~/Library/Application Support/Snug/zoom.json` | 各 App 字号级数 |
| `~/Library/Application Support/Snug/left-behind.json` | 未能立即恢复的窗口记录 |
| `~/Library/Logs/Snug.log` | 运行日志 |

数据路径保留旧名是明确的兼容策略，不应作为 UI 品牌展示。
