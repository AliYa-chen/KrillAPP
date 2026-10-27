# 真机运行与调试

## 环境

- macOS + Xcode 27.2 或更新版本。
- iOS 26.0 或更新版本的 iPhone / iPhone Duo / iPad。
- 用于代码签名的 Apple 账号及开发团队。

## 首次运行

1. 打开 `Krill.xcodeproj`，在左上角选择 **Krill** Scheme。
2. 在项目的 **Krill → Signing & Capabilities** 中打开自动签名，选择你的开发团队。若默认 Bundle Identifier 已被占用，改为自己的唯一标识。
3. 在 Xcode **Product → Destination → Manage Devices** 中完成设备配对。按设备提示启用开发者模式；无线调试需要先按 Xcode 的配对流程完成信任。
4. 在运行目标中选择你的真实设备，点击 Run。
5. 使用 Krill 账号登录，或点击「游客模式查看」查看界面。

项目已配置本机本次调试使用的开发团队 `CC3ZYD9K79`，其他开发者可在 Signing & Capabilities 中更换。命令行可通过 `DEVELOPMENT_TEAM=你的团队ID` 指定团队。

## Duo 验证

分别在折叠外屏和展开内屏检查：费用卡片、Token 构成、热力图、请求明细、筛选面板、键盘弹出和安全区域。窄屏采用单栏；可用宽度充足时采用双栏。切换显示尺寸时应保留当前筛选条件及页面数据。

Duo 机型的尺寸适配与真实折叠切换体验需在设备上验证。通用 iOS 编译成功不等于已经完成真机视觉与交互验证。

登录页按当前可用宽度布局：小于 760pt 时为单栏，包含普通 iPhone、Duo 外屏及较窄的展开竖屏；达到 760pt 时为品牌区与表单双栏。辅助功能大字体使用单栏。布局切换保留输入状态，键盘弹出不改变双栏断点，输入区域可滚动。

## 演示空间

登录页的「游客模式查看」无需账号。自动进入演示空间可在 **Product → Scheme → Edit Scheme → Run → Arguments** 中添加 `--demo`。

演示状态应与真实账号数据清楚区分。演示数据不上传服务器。退出演示后可使用真实账号登录。

## 接口与凭据

默认服务地址为 `https://www.krill-code.com`，会话认证采用 `Authorization: Bearer …`。应用不在工程文件中保存账号密码、测试令牌或 Cookie。登录令牌由系统钥匙串保存。

登录错误、网络错误和过期会话会在界面中显示；服务端返回的数据字段或认证策略变化时，需要同步更新 `Krill/Services` 中的解析逻辑。

## 本地构建与测试

编译通用真机产物：

```sh
xcodebuild -project Krill.xcodeproj -scheme Krill \
  -configuration Debug -destination 'generic/platform=iOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

在已配对设备上运行测试：

```sh
xcodebuild -project Krill.xcodeproj -scheme Krill \
  -destination 'platform=iOS,id=设备ID' \
  DEVELOPMENT_TEAM=你的团队ID test
```

运行测试需要签名和设备支持。上述命令是操作说明，不代表已经在你的设备上执行完成。
