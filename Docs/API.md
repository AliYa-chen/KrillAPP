# 数据接口与统计口径

基于 2026-10-27 官网发布的 `api-B1FA-rVw.js`、请求日志页面和五个接口的授权只读响应核对。旧的 `api-BdBSngwN.js` 已返回 404。测试凭据不保存在本工程中。

## 认证

服务地址固定为 `https://www.krill-code.com`。登录以 JSON 发送邮箱和密码，接收 `data.token`；开启 TOTP 时先取得 `requires_totp` 和 `pending_token`，再提交六位验证码。邮箱验证码登录也使用官网相同接口。

会话接口发送 `Authorization: Bearer <token>`。令牌保存在 iOS 钥匙串，密码不持久化。网络会话关闭 Cookie 接收与自动发送，不需要浏览器 Cookie。HTTP 401 会清理过期会话并返回登录页。

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
| 近 7 天 / 近 30 天 | 包含今天的自然日范围，末端截至当前时刻 |
| 缓存命中率 | 优先 `cache_rate_read_tokens / cache_rate_eligible_tokens`；缺失时使用缓存读取 /（输入 + 缓存写入 + 缓存读取） |
| 请求热力图 | 七次按日统计的小时桶；检查 `bucket_seconds` 及小时请求总量一致性，不完整日期不伪装成零请求 |
| 模型分布 | `/api/request-logs/model-stats` 的 `items`，按费用排序 |
| 订阅额度 | `/api/subscription/quota-usage` 的 `used_usd` / `limit_usd` |
| 扣费来源 | `/api/request-logs/quota-summary` 的当日额度、结转额度、订阅与余额费用 |
| 请求详情 | `/api/request-logs` 的 `items`；状态、用时、输入输出与缓存量 |

费用字段可能是十进制字符串；可空 Token 字段归零。服务端没有请求唯一 ID，界面“记录标识”由页码、序号、时间和模型生成，用于区分列表条目，不作为服务端请求 ID。

主统计解析失败会显示错误，不显示假零值；补充接口失败会显示对应提示。切换筛选时清除旧范围内容，过时的异步返回不能覆盖新的查询。
