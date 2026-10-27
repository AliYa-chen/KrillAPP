# 数据接口与统计口径

基于 2026-10-27 官网发布的 `api-B1FA-rVw.js`、请求日志页面和五个接口的授权只读响应核对。旧的 `api-BdBSngwN.js` 已返回 404。测试凭据不保存在本工程中。

## 认证

服务地址固定为 `https://www.krill-code.com`。登录以 JSON 发送邮箱和密码，接收 `data.token`；开启 TOTP 时先取得 `requires_totp` 和 `pending_token`，再提交六位验证码。邮箱验证码登录也使用官网相同接口。

会话接口发送 `Authorization: Bearer <token>`。令牌保存在 iOS 钥匙串，密码不持久化。网络会话关闭 Cookie 接收与自动发送，不需要浏览器 Cookie。HTTP 401 会清理过期会话并返回登录页。

邮箱验证码重发倒计时使用接口的 `resend_after_seconds`。注册、隐私政策、用户协议和支持地区链接打开官网对应页面。

## 查询

请求日志、统计、模型统计、额度使用和扣费汇总都使用 **POST**，不是 GET。JSON 筛选字段包括：

```json
{
  "start_time": "2026-10-27T00:00:00",
  "end_time": "2026-10-27T17:30:00",
  "model": "model-name",
  "token_id": 123,
  "charge_type": "plan",
  "method": 3
}
```

未选中的条件省略。请求列表另带 `page` 和 `page_size`；应用按 30 条加载。`charge_type` 支持 `plan` / `balance`，`method` 是数字枚举。查询时间无时区后缀，按北京时间 UTC+8 解释；响应的 `request_time`、`bucket_start` 使用 UTC ISO 8601，再转换为北京时间显示。

## 展示映射

| 内容 | 来源与口径 |
| --- | --- |
| 今日费用、请求数与 Token 条 | `/api/request-logs/stats`，今日零点至当前时刻 |
| 本月费用 | 同一接口，本月一日至当前时刻 |
| 较昨日同期 | 今日费用与昨天零点至昨日相同时刻的费用比较；昨日为零时不显示比例 |
| 24 小时 / 7 天 / 30 天 | 与官网使用统计页一致，按当前时刻向前计算滚动时间范围 |
| 缓存命中率 | 优先 `cache_rate_read_tokens / cache_rate_eligible_tokens`；缺失时使用缓存读取 /（输入 + 缓存写入 + 缓存读取） |
| 请求热力图 | 七次按日统计的小时桶；检查 `bucket_seconds` 及小时请求总量一致性，不完整日期不伪装成零请求 |
| 模型分布 | `/api/request-logs/model-stats` 的 `items`，可按请求数、Tokens 或费用排序 |
| 订阅额度 | `/api/subscription/quota-usage` 的 `used_usd` / `limit_usd` |
| 扣费来源 | `/api/request-logs/quota-summary` 的当日额度、结转额度、订阅与余额费用 |
| 请求详情 | `/api/request-logs` 的 `items`；状态、用时、输入输出与缓存量 |

2026-10-27 对照官网 `/app/activity` 后，统计总览采用请求花费、额度扣减、请求数、Tokens 四项摘要。模型分布可按请求数、Tokens、费用排序。额度扣减总额等于 `total_plan_cost_usd + total_credit_cost_usd`；没有独立扣减时间序列时只显示真实来源构成，不复用请求费用曲线。

状态筛选值：成功 `1`、异常 `0`、参数错误 `400`、审核拦截 `451`、连接中 `102`。它们与返回的 HTTP 状态不同，例如成功记录仍显示 `200`／`201`。请求详情还展示渠道、接入点、首 Token 耗时、总耗时、推理强度、套餐扣费和余额扣费；缺失的可选值显示为横线。

费用字段可能是十进制字符串；可空 Token 字段归零。服务端没有请求唯一 ID，界面“记录标识”由页码、序号、时间和模型生成，用于区分列表条目，不作为服务端请求 ID。

主统计解析失败会显示错误，不显示假零值；补充接口失败会显示对应提示。切换筛选时清除旧范围内容，过时的异步返回不能覆盖新的查询。
