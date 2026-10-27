import SwiftUI

struct LoginView: View {
    @Bindable var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var usesCode = false
    @State private var working = false
    @State private var sendingCode = false
    @State private var sentCode = false
    @State private var secondsUntilResend = 0
    @State private var showPassword = false
    @State private var website: LoginWebDestination?
    @AppStorage("appearance") private var appearance = "system"
    @FocusState private var focusedField: Field?

    private enum Field { case email, password, code }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 760 && !dynamicTypeSize.isAccessibilitySize
            let horizontalPadding: CGFloat = wide ? 40 : 20
            let verticalPadding: CGFloat = wide ? 28 : 20
            let availableWidth = min(1040, max(0, geometry.size.width - horizontalPadding * 2))
            let formWidth = wide ? min(432, availableWidth * 0.54) : min(440, availableWidth)
            let layout = wide
                ? AnyLayout(HStackLayout(alignment: .center, spacing: 44))
                : AnyLayout(VStackLayout(alignment: .center, spacing: 24))

            ScrollViewReader { scroll in
                ScrollView {
                    layout {
                        LoginBrandPanel(expanded: wide)
                            .frame(width: wide ? max(0, availableWidth - formWidth - 44) : formWidth)
                        VStack(spacing: 18) {
                            form
                            footer
                        }
                        .frame(width: formWidth)
                    }
                    .frame(maxWidth: 1040)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: max(0, geometry.size.height - verticalPadding * 2), alignment: .center)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, verticalPadding)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: focusedField) { _, field in
                    guard let field else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        scroll.scrollTo(field, anchor: .center)
                    }
                }
                .onChange(of: geometry.size.height) { _, _ in
                    guard let field = focusedField else { return }
                    scroll.scrollTo(field, anchor: .center)
                }
            }
            .background(KrillBackground())
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { focusedField = nil }
            }
        }
        .sheet(item: $website) { destination in
            OfficialWebsiteView(destination: destination)
        }
        .task(id: secondsUntilResend) {
            guard secondsUntilResend > 0 else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            secondsUntilResend -= 1
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top) {
                    formHeading.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 12)
                    appearanceMenu
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Spacer(); appearanceMenu }
                    formHeading
                }
            }

            if store.pendingTOTP {
                codeField
            } else {
                Picker("登录方式", selection: $usesCode) {
                    Text("密码登录").tag(false)
                    Text("验证码登录").tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(working)
                .onChange(of: usesCode) { _, _ in
                    store.errorMessage = nil
                    code = ""
                    focusedField = .email
                }

                labeledField("邮箱") {
                    TextField("you@example.com", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = usesCode ? .code : .password }
                }
                .id(Field.email)

                if usesCode {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .bottom, spacing: 10) {
                            codeField.frame(minWidth: 140)
                            sendCodeButton
                        }
                        VStack(alignment: .trailing, spacing: 10) {
                            codeField
                            sendCodeButton
                        }
                    }
                    if sentCode {
                        Text("验证码已发送，请检查邮箱")
                            .font(.caption).foregroundStyle(KrillTheme.muted)
                    }
                } else {
                    labeledField("密码") {
                        HStack(spacing: 10) {
                            Group {
                                if showPassword {
                                    TextField("至少 6 位", text: $password)
                                } else {
                                    SecureField("至少 6 位", text: $password)
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
                    .id(Field.password)
                }
            }

            if let message = store.errorMessage, !message.isEmpty {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.updatesFrequently)
            }

            Button {
                Task { await signIn() }
            } label: {
                HStack(spacing: 10) {
                    if working && !sendingCode { ProgressView().tint(.white) }
                    Text(store.pendingTOTP ? "验证并登录" : "登录")
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(canSignIn ? Color.white : KrillTheme.muted)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(canSignIn ? KrillTheme.accent : KrillTheme.surfaceMuted, in: Capsule())
                .glassEffect(.regular.tint(canSignIn ? KrillTheme.accent.opacity(0.18) : .clear).interactive(), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canSignIn || working)
            .opacity(working ? 0.7 : 1)
            .accessibilityIdentifier("login.submit")

            if store.pendingTOTP {
                Button("返回登录") {
                    store.logout()
                    code = ""
                }
                .font(.subheadline)
                .foregroundStyle(KrillTheme.muted)
                .frame(maxWidth: .infinity)
                .disabled(working)
            } else {
                HStack(spacing: 5) {
                    Text("还没有账号？").foregroundStyle(KrillTheme.muted)
                    Button("去注册") { openWebsite("/register") }
                        .foregroundStyle(KrillTheme.accent)
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
            }

            separator(nil)

            Button {
                focusedField = nil
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { store.enterDemo() }
            } label: {
                Label("游客模式查看", systemImage: "person.crop.circle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(KrillTheme.muted)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(working)
            .accessibilityIdentifier("login.demo")
        }
        .padding(2)
        .krillCard(cornerRadius: 30)
    }

    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { policyLinks }
            VStack(spacing: 12) { policyLinks }
        }
        .font(.caption2)
        .foregroundStyle(KrillTheme.muted)
        .buttonStyle(.plain)
    }

    private var formHeading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.pendingTOTP ? "两步验证" : "欢迎回来")
                .font(.title2.weight(.semibold))
            Text(store.pendingTOTP ? "输入验证器生成的六位动态验证码。" : "使用你的 Krill 账号登录")
                .font(.caption)
                .foregroundStyle(KrillTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appearanceMenu: some View {
        Menu {
            Picker("外观", selection: $appearance) {
                Text("跟随系统").tag("system")
                Text("白色").tag("light")
                Text("黑夜").tag("dark")
            }
        } label: {
            Label("外观", systemImage: "circle.lefthalf.filled")
                .font(.caption)
                .foregroundStyle(KrillTheme.muted)
                .padding(.horizontal, 8)
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .accessibilityIdentifier("login.appearance")
    }

    @ViewBuilder private var policyLinks: some View {
        Button("隐私政策") { openWebsite("/privacy-policy") }
        Button("用户协议") { openWebsite("/terms-of-service") }
        Button("支持的国家和地区") { openWebsite("/supported-regions") }
    }

    private func separator(_ title: String?) -> some View {
        HStack(spacing: 12) {
            Rectangle().fill(KrillTheme.grid).frame(height: 1)
            if let title {
                Text(title).font(.caption).foregroundStyle(KrillTheme.muted).fixedSize()
                Rectangle().fill(KrillTheme.grid).frame(height: 1)
            }
        }
    }

    private var codeField: some View {
        labeledField("验证码") {
            TextField("六位验证码", text: $code)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .code)
                .onChange(of: code) { _, newValue in code = String(newValue.filter(\.isNumber).prefix(6)) }
        }
        .id(Field.code)
    }

    private var sendCodeButton: some View {
        Button {
            Task { await sendCode() }
        } label: {
            Group {
                if sendingCode { ProgressView().controlSize(.small) }
                else { Text(secondsUntilResend > 0 ? "\(secondsUntilResend)s 后重发" : "发送验证码") }
            }
            .font(.caption.weight(.medium))
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 12)
            .frame(minHeight: 52)
            .background(KrillTheme.surfaceMuted.opacity(0.55), in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(KrillTheme.border, lineWidth: 0.7))
        }
        .buttonStyle(.plain)
        .foregroundStyle(KrillTheme.text)
        .disabled(!validEmail || working || secondsUntilResend > 0)
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(KrillTheme.text)
            content()
                .font(.body)
                .padding(.horizontal, 15)
                .frame(minHeight: 52)
                .background(KrillTheme.surface.opacity(0.78), in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(KrillTheme.border, lineWidth: 0.8))
                .disabled(working)
        }
    }

    private var validEmail: Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
            .range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }

    private var canSignIn: Bool {
        if store.pendingTOTP { return code.count == 6 }
        return validEmail && (usesCode ? code.count == 6 : password.count >= 6)
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
        guard validEmail, !working, secondsUntilResend == 0 else { return }
        working = true
        sendingCode = true
        let cooldown = await store.sendLoginCode(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
        working = false
        sendingCode = false
        if let cooldown {
            sentCode = true
            secondsUntilResend = max(1, cooldown)
        }
    }

    private func openWebsite(_ path: String) {
        guard let url = URL(string: "https://www.krill-code.com" + path) else { return }
        focusedField = nil
        website = LoginWebDestination(url: url)
    }
}
