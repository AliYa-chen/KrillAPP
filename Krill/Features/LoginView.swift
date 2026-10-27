import SwiftUI

struct LoginView: View {
    @Bindable var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var usesCode = false
    @State private var working = false
    @State private var sentCode = false
    @State private var secondsUntilResend = 0
    @State private var showPassword = false
    @AppStorage("appearance") private var appearance = "system"
    @FocusState private var focusedField: Field?
    private enum Field { case email, password, code }

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= 700
            ZStack {
                KrillBackground()
                ScrollView {
                    Group {
                        if wide {
                            HStack(spacing: 56) {
                                introduction(wide: true)
                                    .frame(maxWidth: 450, alignment: .leading)
                                form.frame(maxWidth: 410)
                            }
                            .frame(maxWidth: 960)
                        } else {
                            VStack(spacing: 36) {
                                introduction(wide: false)
                                form
                            }
                            .frame(maxWidth: 450)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: max(0, proxy.size.height - 64))
                    .padding(.horizontal, wide ? 44 : 24)
                    .padding(.vertical, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .task(id: secondsUntilResend) {
            guard secondsUntilResend > 0 else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            secondsUntilResend -= 1
        }
    }

    private func introduction(wide: Bool) -> some View {
        VStack(alignment: wide ? .leading : .center, spacing: 20) {
            Image("KrillLogo")
                .resizable()
                .scaledToFit()
                .frame(width: wide ? 160 : 140)
                .accessibilityLabel("Krill")
            .padding(.bottom, wide ? 28 : 12)

            VStack(alignment: wide ? .leading : .center, spacing: 8) {
                Text("每一次调用，")
                    .foregroundStyle(KrillTheme.text)
                Text("都清晰可见。")
                    .foregroundStyle(KrillTheme.accent)
            }
            .font(.system(size: wide ? 46 : 35, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.8)
            .accessibilityElement(children: .combine)

            Text("你的 AI 用量，拥有全新视角。")
                .font(.system(size: 15))
                .foregroundStyle(KrillTheme.muted)

            if wide {
                HStack(spacing: 22) {
                    feature("chart.bar.xaxis", "用量趋势")
                    feature("square.grid.3x3.fill", "活跃热力")
                    feature("sparkles", "模型洞察")
                }
                .padding(.top, 26)
            }
        }
        .multilineTextAlignment(wide ? .leading : .center)
    }

    private func feature(_ icon: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.system(size: 21)).foregroundStyle(KrillTheme.cyan)
            Text(title).font(.system(size: 12)).foregroundStyle(KrillTheme.muted)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(store.pendingTOTP ? "两步验证" : "欢迎回来")
                        .font(.system(size: 24, weight: .semibold))
                    Spacer()
                    Image(systemName: store.pendingTOTP ? "lock.shield" : "waveform.path")
                        .foregroundStyle(KrillTheme.cyan)
                }
                Text(store.pendingTOTP ? "输入验证器生成的六位动态验证码。" : "使用你的 Krill 账号登录")
                    .font(.system(size: 13))
                    .foregroundStyle(KrillTheme.muted)
            }

            if !store.pendingTOTP {
                Picker("登录方式", selection: $usesCode) {
                    Text("密码登录").tag(false)
                    Text("邮箱验证码").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: usesCode) { _, _ in
                    store.errorMessage = nil
                    code = ""
                }

                labeledField("邮箱", icon: "envelope") {
                    TextField("you@example.com", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = usesCode ? .code : .password }
                }

                if usesCode {
                    codeField
                    HStack(spacing: 8) {
                        if sentCode {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(KrillTheme.cyan)
                            Text("验证码已发送，请检查邮箱")
                                .foregroundStyle(KrillTheme.muted)
                        }
                        Spacer(minLength: 0)
                        Button(secondsUntilResend > 0 ? "\(secondsUntilResend)s 后重发" : "获取验证码") {
                            Task { await sendCode() }
                        }
                        .foregroundStyle(KrillTheme.cyan)
                        .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || working || secondsUntilResend > 0)
                    }
                    .font(.system(size: 12))
                } else {
                    labeledField("密码", icon: "lock") {
                        HStack {
                            Group {
                                if showPassword {
                                    TextField("输入密码", text: $password)
                                } else {
                                    SecureField("输入密码", text: $password)
                                }
                            }
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await signIn() } }
                            Button { showPassword.toggle() } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(KrillTheme.muted)
                            }
                            .accessibilityLabel(showPassword ? "隐藏密码" : "显示密码")
                        }
                    }
                }
            } else {
                codeField
            }

            if let message = store.errorMessage, !message.isEmpty {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.updatesFrequently)
            }

            Button {
                Task { await signIn() }
            } label: {
                HStack(spacing: 12) {
                    if working { ProgressView().tint(Color.white) }
                    Text(store.pendingTOTP ? "验证并登录" : "进入控制台")
                    if !working { Image(systemName: "arrow.up.right") }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(KrillTheme.accent, in: Capsule())
                .glassEffect(.regular.tint(KrillTheme.accent.opacity(0.2)).interactive(), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canSignIn || working)
            .opacity(canSignIn && !working ? 1 : 0.45)
            .accessibilityIdentifier("login.submit")

            if store.pendingTOTP {
                Button("返回登录") {
                    store.logout()
                    code = ""
                }
                .font(.system(size: 13))
                .foregroundStyle(KrillTheme.muted)
                .frame(maxWidth: .infinity)
                .disabled(working)
            }

            HStack(spacing: 14) {
                Rectangle().fill(KrillTheme.text.opacity(0.1)).frame(height: 1)
                Text("先看一看").font(.system(size: 11)).foregroundStyle(KrillTheme.muted)
                Rectangle().fill(KrillTheme.text.opacity(0.1)).frame(height: 1)
            }

            Button {
                focusedField = nil
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { store.enterDemo() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle")
                    Text("探索演示空间")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(KrillTheme.text.opacity(0.8))
                .frame(maxWidth: .infinity)
            }
            .disabled(working)
            .accessibilityIdentifier("login.demo")

            HStack(spacing: 5) {
                Image(systemName: "lock.shield").font(.system(size: 10))
                Text("安全连接至 krill-code.com")
            }
            .font(.system(size: 10))
            .foregroundStyle(KrillTheme.muted.opacity(0.8))
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                Menu {
                    Picker("外观", selection: $appearance) {
                        Text("跟随系统").tag("system")
                        Text("白色").tag("light")
                        Text("黑夜").tag("dark")
                    }
                } label: {
                    Label("外观", systemImage: "circle.lefthalf.filled")
                        .font(.system(size: 12))
                        .foregroundStyle(KrillTheme.muted)
                }
                Spacer()
            }
        }
        .padding(26)
        .krillCard(cornerRadius: 32)
    }

    private var codeField: some View {
        labeledField("验证码", icon: "number") {
            TextField("六位验证码", text: $code)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .code)
                .onChange(of: code) { _, newValue in
                    code = String(newValue.filter(\.isNumber).prefix(6))
                }
        }
    }

    private func labeledField<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(KrillTheme.muted)
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 18).foregroundStyle(KrillTheme.muted)
                content().font(.system(size: 15))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 54)
            .background(KrillTheme.text.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(KrillTheme.text.opacity(0.08)))
        }
    }

    private var canSignIn: Bool {
        if store.pendingTOTP { return code.count == 6 }
        return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (usesCode ? code.count == 6 : !password.isEmpty)
    }

    @MainActor private func signIn() async {
        guard canSignIn, !working else { return }
        focusedField = nil
        working = true
        defer { working = false }
        if store.pendingTOTP {
            await store.verifyTOTP(code: code)
        } else if usesCode {
            await store.loginWithCode(email: email.trimmingCharacters(in: .whitespacesAndNewlines), code: code)
        } else {
            await store.login(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        }
        if store.pendingTOTP { code = "" }
        if store.isAuthenticated { password = ""; code = "" }
    }

    @MainActor private func sendCode() async {
        guard !working else { return }
        working = true
        await store.sendLoginCode(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
        working = false
        if store.errorMessage == nil {
            sentCode = true
            secondsUntilResend = 60
        }
    }
}
