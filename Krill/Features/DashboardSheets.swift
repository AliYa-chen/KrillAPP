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
                        Label(log.isSuccess ? "请求成功" : "请求异常", systemImage: log.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.caption).foregroundStyle(log.isSuccess ? KrillTheme.green : KrillTheme.amber)
                        Text(log.model).font(.title2.weight(.bold)).textSelection(.enabled)
                        Text(KrillFormat.money(log.cost, precision: 6))
                            .font(.system(size: amountSize, weight: .semibold, design: .rounded)).monospacedDigit()
                        Text(KrillFormat.date(log.date, pattern: "yyyy年M月d日 HH:mm:ss") + " · UTC+8")
                            .font(.caption).foregroundStyle(KrillTheme.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading).krillCard()
                    VStack(spacing: 18) {
                        detail("输入 Tokens", value: KrillFormat.number(log.inputTokens))
                        detail("输出 Tokens", value: KrillFormat.number(log.outputTokens))
                        detail("缓存读取", value: KrillFormat.number(log.cacheReadTokens))
                        detail("缓存写入", value: KrillFormat.number(log.cacheWriteTokens))
                        detail("思考 Tokens", value: KrillFormat.number(log.reasoningTokens))
                    }.krillCard()
                    VStack(spacing: 18) {
                        detail("耗时", value: (log.durationMS / 1000).formatted(.number.precision(.fractionLength(2))) + " s")
                        detail("状态", value: log.status)
                        detail("协议", value: protocolName(log.method))
                        detail("API Key", value: log.tokenName.isEmpty ? "—" : log.tokenName)
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
    }
    private func protocolName(_ value: String) -> String {
        ["1": "Anthropic Messages", "2": "Chat Completions", "3": "Responses", "4": "远程压缩", "5": "图像生成", "6": "图像编辑", "7": "视频生成", "9": "搜索", "10": "语音合成", "11": "语音转写", "12": "实时通话", "13": "上下文管理", "14": "后台压缩"][value] ?? (value.isEmpty ? "—" : value)
    }
}
