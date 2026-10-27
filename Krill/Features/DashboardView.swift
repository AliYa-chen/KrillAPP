import SwiftUI

struct DashboardView: View {
    @Bindable var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("appearance") private var appearance = "system"
    @State private var selection: DashboardTab = .overview
    @State private var showingFilters = false
    @State private var selectedLog: RequestLog?
    @State private var selectedHour: HourCell?
    @State private var confirmingLogout = false

    private enum DashboardTab: Hashable { case overview, logs, account }

    var body: some View {
        TabView(selection: $selection) {
            Tab("概览", systemImage: "square.grid.2x2.fill", value: .overview) {
                NavigationStack {
                    GeometryReader { geometry in
                        ScrollView {
                            overview(wide: geometry.size.width >= 700 && !dynamicTypeSize.isAccessibilitySize)
                                .padding(.horizontal, geometry.size.width >= 700 ? 28 : 20)
                                .padding(.top, 8).padding(.bottom, 28)
                                .frame(maxWidth: 1380).frame(maxWidth: .infinity)
                        }
                        .refreshable { await store.refresh() }
                    }
                    .background(KrillBackground())
                    .toolbar { dashboardToolbar }
                    .toolbarBackground(.hidden, for: .navigationBar)
                }
            }
            Tab("请求", systemImage: "waveform.path", value: .logs) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            pageHeading("请求记录", subtitle: store.filter.period.label + " · 北京时间")
                            if let message = store.errorMessage { errorCard(message) }
                            requestPanel(limit: nil)
                        }.padding(20).frame(maxWidth: 1000).frame(maxWidth: .infinity)
                    }
                    .refreshable { await store.refresh() }
                    .background(KrillBackground())
                    .toolbar { dashboardToolbar }
                    .toolbarBackground(.hidden, for: .navigationBar)
                }
            }
            Tab("账户", systemImage: "person.crop.circle", value: .account) {
                NavigationStack { account }
            }
        }
        .tint(KrillTheme.accent)
        .sheet(isPresented: $showingFilters) { DashboardFilterSheet(store: store) }
        .sheet(item: $selectedLog) { DashboardLogDetail(log: $0) }
        .confirmationDialog("退出当前账户？", isPresented: $confirmingLogout, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) { store.logout() }
            Button("取消", role: .cancel) {}
        }
        .task { if store.snapshot == nil { await store.refresh() } }
        .onChange(of: store.snapshot?.updatedAt) { _, _ in selectedHour = nil }
    }

    @ToolbarContentBuilder private var dashboardToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Image("KrillLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 86, height: 37)
                .accessibilityLabel("Krill")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if store.isDemo {
                Text("演示").font(.system(size: 10, weight: .semibold)).foregroundStyle(KrillTheme.amber)
            }
            Button { showingFilters = true } label: { Image(systemName: "line.3.horizontal.decrease") }
                .accessibilityLabel("筛选用量")
            Button { Task { await store.refresh() } } label: {
                if store.isLoading { ProgressView().controlSize(.small) }
                else { Image(systemName: "arrow.clockwise") }
            }
            .disabled(store.isLoading).accessibilityLabel("刷新用量")
        }
    }

    private func overview(wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            pageHeading("用量概览", subtitle: KrillFormat.date(Date(), pattern: "M月d日 EEEE") + " · 北京时间")
            HStack {
                Picker("统计周期", selection: $store.filter.period) {
                    ForEach(UsagePeriod.allCases) { period in Text(period.label).tag(period) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: wide ? 320 : .infinity)
                .onChange(of: store.filter.period) { _, _ in Task { await store.refresh() } }
                if wide { Spacer() }
                if filterCount > 0 {
                    Button { showingFilters = true } label: {
                        Label("\(filterCount)", systemImage: "line.3.horizontal.decrease")
                            .font(.caption).padding(9)
                    }.glassEffect(in: .capsule)
                }
            }
            if let message = store.errorMessage { errorCard(message) }
            ForEach(store.warnings, id: \.self) { warning in errorCard(warning) }
            if let snapshot = store.snapshot {
                if wide {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(spacing: 20) {
                            TodayCard(snapshot: snapshot, selectedHour: $selectedHour)
                            SpendTrendCard(points: snapshot.trend, period: store.filter.period.label, total: snapshot.stats.cost)
                            QuotaCard(quotas: snapshot.quotas, summary: snapshot.quotaSummary)
                        }.frame(maxWidth: .infinity)
                        VStack(spacing: 20) {
                            periodMetrics(snapshot)
                            ModelUsageCard(models: snapshot.models)
                            requestPanel(limit: 6)
                        }.frame(maxWidth: .infinity)
                    }
                } else {
                    TodayCard(snapshot: snapshot, selectedHour: $selectedHour)
                    periodMetrics(snapshot)
                    SpendTrendCard(points: snapshot.trend, period: store.filter.period.label, total: snapshot.stats.cost)
                    ModelUsageCard(models: snapshot.models)
                    QuotaCard(quotas: snapshot.quotas, summary: snapshot.quotaSummary)
                    requestPanel(limit: 4)
                }
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                    Text("更新于 " + KrillFormat.date(snapshot.updatedAt, pattern: "HH:mm:ss"))
                    if store.isDemo { Text("· 演示数据") }
                }.font(.system(size: 10)).foregroundStyle(KrillTheme.muted).frame(maxWidth: .infinity)
            } else if store.isLoading {
                VStack(spacing: 14) {
                    ProgressView().tint(KrillTheme.accent)
                    Text("正在获取用量").font(.caption).foregroundStyle(KrillTheme.muted)
                }.frame(maxWidth: .infinity, minHeight: 300)
            } else {
                ContentUnavailableView {
                    Label("暂无用量数据", systemImage: "chart.bar.xaxis")
                } description: {
                    Text("刷新后查看你的请求与消耗。")
                } actions: {
                    Button("重新加载") { Task { await store.refresh() } }.buttonStyle(.bordered)
                }.frame(minHeight: 300)
            }
        }
    }

    private func pageHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(subtitle).font(.system(size: 11, weight: .medium)).foregroundStyle(KrillTheme.muted).tracking(0.6)
            Text(title).font(.largeTitle.weight(.bold)).tracking(-0.5).foregroundStyle(KrillTheme.text)
        }.padding(.vertical, 8)
    }

    private func periodMetrics(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionEyebrow(title: "\(store.filter.period.label)统计")
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
                MetricTile(title: "总请求", value: snapshot.stats.requests.formatted(), symbol: "arrow.up.arrow.down")
                MetricTile(title: "总 Tokens", value: KrillFormat.number(snapshot.stats.totalTokens), symbol: "sparkles", tint: KrillTheme.violet)
                MetricTile(title: "缓存命中", value: KrillFormat.percent(snapshot.stats.cacheHitRate), symbol: "bolt.fill", tint: KrillTheme.green)
                MetricTile(title: "思考 Tokens", value: KrillFormat.number(snapshot.stats.reasoningTokens), symbol: "brain", tint: KrillTheme.amber)
            }
        }
    }

    private var filterCount: Int {
        (store.filter.model.isEmpty ? 0 : 1) + (store.filter.tokenID == nil ? 0 : 1) + (store.filter.chargeType.isEmpty ? 0 : 1) + (store.filter.method.isEmpty ? 0 : 1)
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(KrillTheme.amber)
            Text(message).font(.caption).foregroundStyle(KrillTheme.text)
            Spacer(minLength: 0)
        }
        .padding(14).background(KrillTheme.amber.opacity(0.09), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private func requestPanel(limit: Int?) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                SectionEyebrow(title: limit == nil ? "调用明细" : "最近请求")
                if limit != nil {
                    Button("全部") { selection = .logs }.font(.system(size: 11, weight: .medium))
                }
            }
            if let snapshot = store.snapshot, !snapshot.logs.isEmpty {
                let logs = limit.map { Array(snapshot.logs.prefix($0)) } ?? snapshot.logs
                ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                    if index > 0 { Rectangle().fill(KrillTheme.grid).frame(height: 1) }
                    Button { selectedLog = log } label: { DashboardLogRow(log: log) }.buttonStyle(.plain)
                }
                if limit == nil, store.hasMoreLogs {
                    Button {
                        Task { await store.loadMoreLogs() }
                    } label: {
                        HStack {
                            Spacer()
                            if store.isLoadingMore { ProgressView().controlSize(.small) }
                            else { Text("加载更多请求").font(.caption) }
                            Spacer()
                        }.padding(.vertical, 12)
                    }.disabled(store.isLoadingMore)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "tray").font(.system(size: 24)).foregroundStyle(KrillTheme.muted)
                    Text(store.isLoading ? "正在获取请求" : "所选条件下暂无请求").font(.caption).foregroundStyle(KrillTheme.muted)
                }.frame(maxWidth: .infinity, minHeight: 100)
            }
        }.krillCard()
    }

    private var account: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeading("我的账户", subtitle: "www.krill-code.com")
                VStack(spacing: 18) {
                    KrillMark(size: 64)
                    Text(store.userDisplayName).font(.title3.weight(.semibold))
                    Label(store.isDemo ? "演示模式" : "已安全连接", systemImage: store.isDemo ? "play.circle" : "checkmark.shield.fill")
                        .font(.caption).foregroundStyle(store.isDemo ? KrillTheme.amber : KrillTheme.green)
                }.frame(maxWidth: .infinity).padding(.vertical, 10).krillCard()
                VStack(alignment: .leading, spacing: 20) {
                    accountLine("服务地址", value: "www.krill-code.com", symbol: "network")
                    accountLine("统计时区", value: "北京时间 UTC+8", symbol: "globe.asia.australia")
                    accountLine("显示模式", value: "跟随窗口自动布局", symbol: "rectangle.split.2x1")
                    Link(destination: URL(string: "https://www.krill-code.com")!) {
                        HStack {
                            Label("打开 Krill 控制台", systemImage: "arrow.up.forward.app")
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.caption)
                        }.font(.subheadline)
                    }
                }.krillCard()
                VStack(alignment: .leading, spacing: 16) {
                    SectionEyebrow(title: "外观")
                    Picker("界面外观", selection: $appearance) {
                        Text("跟随系统").tag("system")
                        Text("白色").tag("light")
                        Text("黑夜").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }.krillCard()
                Button(role: .destructive) { confirmingLogout = true } label: {
                    Label(store.isDemo ? "退出演示模式" : "退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity).padding(15)
                }.buttonStyle(.glass)
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
        .background(KrillBackground())
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func accountLine(_ title: String, value: String, symbol: String) -> some View {
        HStack {
            Label(title, systemImage: symbol).foregroundStyle(KrillTheme.muted)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }.font(.system(size: 12))
    }
}

struct DashboardLogRow: View {
    let log: RequestLog
    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 11).fill((log.isSuccess ? KrillTheme.cyan : KrillTheme.amber).opacity(0.09))
                Image(systemName: log.isSuccess ? "arrow.up.right" : "exclamationmark")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(log.isSuccess ? KrillTheme.cyan : KrillTheme.amber)
            }.frame(width: 35, height: 35)
            VStack(alignment: .leading, spacing: 6) {
                Text(log.model).font(.subheadline.weight(.semibold)).foregroundStyle(KrillTheme.text).lineLimit(1)
                HStack(spacing: 5) {
                    Text(KrillFormat.date(log.date, pattern: "MM/dd HH:mm:ss"))
                    Text("·")
                    Text(log.isSuccess ? "成功" : log.status)
                }.font(.caption2).foregroundStyle(KrillTheme.muted).lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 6) {
                Text(KrillFormat.money(log.cost, precision: 4)).font(.system(.caption, design: .rounded, weight: .medium)).foregroundStyle(KrillTheme.text)
                Text(KrillFormat.number(log.inputTokens + log.outputTokens + log.cacheReadTokens + log.cacheWriteTokens) + " tokens").font(.caption2).foregroundStyle(KrillTheme.muted)
            }.monospacedDigit()
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("查看请求详情")
    }
}
