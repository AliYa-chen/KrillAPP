import SwiftUI

struct DashboardFilterSheet: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: UsageFilter

    init(store: AppStore) {
        self.store = store
        _draft = State(initialValue: store.filter)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("时间范围") {
                    Picker("统计周期", selection: $draft.period) {
                        ForEach(UsagePeriod.allCases) { period in Text(period.label).tag(period) }
                    }.pickerStyle(.segmented)
                }
                Section("请求筛选") {
                    Picker("模型", selection: $draft.model) {
                        Text("全部模型").tag("")
                        ForEach(store.availableModels, id: \.self) { model in Text(model).tag(model) }
                    }
                    Picker("API Key", selection: $draft.tokenID) {
                        Text("全部 Key").tag(Int?.none)
                        ForEach(store.availableTokens) { token in Text(token.name).tag(Optional(token.id)) }
                    }
                    Picker("扣费来源", selection: $draft.chargeType) {
                        Text("全部扣费").tag("")
                        Text("订阅额度").tag("plan")
                        Text("账户余额").tag("balance")
                    }
                    Picker("请求状态", selection: $draft.status) {
                        Text("全部状态").tag(Int?.none)
                        Text("成功").tag(Optional(1))
                        Text("异常").tag(Optional(0))
                        Text("参数错误").tag(Optional(400))
                        Text("审核拦截").tag(Optional(451))
                        Text("连接中").tag(Optional(102))
                    }
                    Picker("协议", selection: $draft.method) {
                        Text("所有协议").tag("")
                        Text("Anthropic Messages").tag("1")
                        Text("Chat Completions").tag("2")
                        Text("Responses").tag("3")
                        Text("远程压缩").tag("4")
                        Text("图像生成").tag("5")
                        Text("图像编辑").tag("6")
                        Text("视频生成").tag("7")
                        Text("搜索").tag("9")
                        Text("语音合成").tag("10")
                        Text("语音转写").tag("11")
                        Text("实时通话").tag("12")
                        Text("上下文管理").tag("13")
                        Text("后台压缩").tag("14")
                    }
                }
                Section {
                    Button("重置筛选") { draft = UsageFilter() }
                        .foregroundStyle(KrillTheme.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(KrillBackground())
            .navigationTitle("筛选用量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        store.filter = draft
                        dismiss()
                        Task { await store.refresh() }
                    }.fontWeight(.semibold)
                }
            }
        }
        .tint(KrillTheme.accent)
        .presentationDragIndicator(.visible)
    }
}

struct DashboardLogDetail: View {
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize = 38.0
    let log: RequestLog
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(log.statusLabel, systemImage: log.isSuccess ? "checkmark.circle.fill" : log.status == "102" ? "clock" : "exclamationmark.circle.fill")
                            .font(.caption).foregroundStyle(log.isSuccess ? KrillTheme.green : KrillTheme.amber)
                        Text(log.model).font(.title2.weight(.bold)).textSelection(.enabled)
                        Text(KrillFormat.money(log.cost, precision: 6))
                            .font(.system(size: amountSize, weight: .semibold, design: .rounded)).monospacedDigit()
                        Text(KrillFormat.date(log.date, pattern: "yyyy年M月d日 HH:mm:ss") + " · UTC+8")
                            .font(.caption).foregroundStyle(KrillTheme.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading).krillCard()
                    VStack(alignment: .leading, spacing: 18) {
                        SectionEyebrow(title: "Token 用量")
                        detail("输入 Tokens", value: tokenCount(log.inputTokens))
                        detail("输出 Tokens", value: tokenCount(log.outputTokens))
                        detail("缓存读取", value: tokenCount(log.cacheReadTokens))
                        detail("缓存写入", value: tokenCount(log.cacheWriteTokens))
                        detail("思考 Tokens", value: tokenCount(log.reasoningTokens))
                    }.krillCard()
                    VStack(alignment: .leading, spacing: 18) {
                        SectionEyebrow(title: "请求信息")
                        detail("状态", value: log.status)
                        detail("渠道", value: available(log.channel))
                        detail("接入点", value: available(log.endpoint))
                        detail("协议", value: protocolName(log.method))
                        detail("推理强度", value: available(log.reasoningEffort))
                        detail("首 Token 耗时", value: log.firstTokenMS.map(duration) ?? "—")
                        detail("总耗时", value: log.durationAvailable ? duration(log.durationMS) : "—")
                        detail("API Key", value: available(log.tokenName))
                    }.krillCard()
                    VStack(alignment: .leading, spacing: 18) {
                        SectionEyebrow(title: "扣费明细")
                        detail("扣费来源", value: available(log.chargeSource))
                        detail("请求费用", value: KrillFormat.money(log.cost, precision: 6))
                        detail("套餐扣费", value: log.planCost.map { KrillFormat.money($0, precision: 6) } ?? "—")
                        detail("余额扣费", value: log.creditCost.map { KrillFormat.money($0, precision: 6) } ?? "—")
                    }.krillCard()
                    if !log.errorMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("请求错误", systemImage: "exclamationmark.circle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(KrillTheme.amber)
                            Text(log.errorMessage)
                                .font(.callout)
                                .foregroundStyle(KrillTheme.text)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }.frame(maxWidth: .infinity, alignment: .leading).krillCard()
                    }
                    VStack(spacing: 18) {
                        detail("记录标识", value: log.id)
                    }.krillCard()
                }.padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .background(KrillBackground())
            .navigationTitle("请求详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .tint(KrillTheme.accent)
        .presentationDragIndicator(.visible)
    }
    private func detail(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            Text(title).font(.caption).foregroundStyle(KrillTheme.muted)
            Spacer()
            Text(value).font(.system(.caption, design: .monospaced, weight: .medium))
                .multilineTextAlignment(.trailing).textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }
    private func available(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : value
    }
    private func tokenCount(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
    private func duration(_ milliseconds: Double) -> String {
        if milliseconds < 1000 {
            return milliseconds.formatted(.number.precision(.fractionLength(0))) + " ms"
        }
        return (milliseconds / 1000).formatted(.number.precision(.fractionLength(2))) + " s"
    }
    private func protocolName(_ value: String) -> String {
        ["1": "Anthropic Messages", "2": "Chat Completions", "3": "Responses", "4": "远程压缩", "5": "图像生成", "6": "图像编辑", "7": "视频生成", "9": "搜索", "10": "语音合成", "11": "语音转写", "12": "实时通话", "13": "上下文管理", "14": "后台压缩"][value] ?? (value.isEmpty ? "—" : value)
    }
}
