# Krill · Insights

面向 iPhone / iPhone Duo / iPad 的原生 SwiftUI 用量仪表盘，使用系统 Liquid Glass。数据来自 `https://www.krill-code.com`。

## 打开工程

使用 Xcode 27.2 或更新版本打开 `Krill.xcodeproj`，选择 **Krill** Scheme。最低系统为 **iOS 26.0**。

真机运行：工程已选择本机用于此次调试的开发团队；需要切换时，在 **Signing & Capabilities** 中选择你的 Apple 开发团队，在 **Product → Destination** 选择已配对的设备，然后运行。详细步骤见 [Docs/SETUP.md](Docs/SETUP.md)。本项目当前调试按真机工作流进行，不要求启动模拟器。

## 功能

- 邮箱密码、邮箱验证码及 TOTP 两步验证登录，令牌存储在系统钥匙串。
- 今日 / 近 7 天 / 近 30 天用量，费用、请求数、Token 构成和缓存命中率。
- 按小时的近七日请求热力图、每日费用趋势、模型用量排行。
- 订阅额度、扣费来源汇总、请求记录与详情。
- 模型、Key、扣费来源和协议筛选，下拉刷新。
- 窄屏单栏、宽屏双栏；窗口尺寸变化时保留页面状态，适合 Duo 外屏与展开内屏。
- 独立演示空间。登录页点击「探索演示空间」，或在 Scheme 的 Launch Arguments 中加入 `--demo`；演示数据会明确标识。
- 白色与黑夜两种外观，默认跟随系统；可在登录页或账户页切换。
- 使用 Krill 官方横版 Logo。

## 接口

| 用途 | 方法与路径 |
| --- | --- |
| 密码登录 | `POST /api/auth/login` |
| 两步验证 | `POST /api/auth/login/totp` |
| 发送邮箱验证码 | `POST /api/auth/login/send-code` |
| 验证邮箱验证码 | `POST /api/auth/login/verify` |
| 当前账号 | `GET /api/auth/me` |
| 请求明细 | `POST /api/request-logs` |
| 统计汇总 | `POST /api/request-logs/stats` |
| 模型汇总 | `POST /api/request-logs/model-stats` |
| 订阅额度 | `POST /api/subscription/quota-usage` |
| 扣费来源 | `POST /api/request-logs/quota-summary` |

接口契约以当前官网客户端为准。工程不包含测试账号、密码、Bearer 令牌或 Cookie。`--demo` 仅切换到本地演示数据，不会自动登录真实账号。

统计映射、时间范围和缓存率口径见 [Docs/API.md](Docs/API.md)。

## 目录

- `Krill/Models`：业务数据与时间范围。
- `Krill/Services`：接口、会话及钥匙串。
- `Krill/Design`：色彩、玻璃材质与视觉组件。
- `Krill/Features`：登录与仪表盘。
- `Krill/Resources`：应用配置与图标。
- `KrillTests`：接口解析、时区、缓存率及小时聚合测试。
- `Package.swift`：在 Mac 上运行核心测试，无需模拟器。

## 构建

无需第三方依赖。下面仅编译真机产物，不安装、不启动设备：

```sh
xcodebuild -project Krill.xcodeproj -scheme Krill \
  -configuration Debug -destination 'generic/platform=iOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

未签名产物不能直接安装到真机。安装、调试和运行测试需要选择开发团队，并使用已配对、启用开发者模式的真实 iOS 设备。

核心数据测试（在 Mac 上执行）：

```sh
swift test
```
