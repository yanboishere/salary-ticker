import SwiftUI
import AppKit
import ServiceManagement

// MARK: - 设置

final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    @Published var monthlySalary: Double { didSet { d.set(monthlySalary, forKey: "monthlySalary") } }
    @Published var startMinutes: Int { didSet { d.set(startMinutes, forKey: "startMinutes") } }
    @Published var endMinutes: Int { didSet { d.set(endMinutes, forKey: "endMinutes") } }
    @Published var lunchEnabled: Bool { didSet { d.set(lunchEnabled, forKey: "lunchEnabled") } }
    @Published var lunchStart: Int { didSet { d.set(lunchStart, forKey: "lunchStart") } }
    @Published var lunchEnd: Int { didSet { d.set(lunchEnd, forKey: "lunchEnd") } }
    /// Calendar weekday: 1=周日 ... 7=周六
    @Published var workdays: Set<Int> { didSet { d.set(Array(workdays), forKey: "workdays") } }
    @Published var useFixedDays: Bool { didSet { d.set(useFixedDays, forKey: "useFixedDays") } }
    @Published var showWidget: Bool { didSet { d.set(showWidget, forKey: "showWidget") } }

    private init() {
        d.register(defaults: [
            "monthlySalary": 8000.0,
            "startMinutes": 9 * 60,
            "endMinutes": 18 * 60,
            "lunchEnabled": true,
            "lunchStart": 12 * 60,
            "lunchEnd": 13 * 60 + 30,
            "workdays": [2, 3, 4, 5, 6],
            "useFixedDays": true,
            "showWidget": true,
        ])
        monthlySalary = d.double(forKey: "monthlySalary")
        startMinutes = d.integer(forKey: "startMinutes")
        endMinutes = d.integer(forKey: "endMinutes")
        lunchEnabled = d.bool(forKey: "lunchEnabled")
        lunchStart = d.integer(forKey: "lunchStart")
        lunchEnd = d.integer(forKey: "lunchEnd")
        workdays = Set((d.array(forKey: "workdays") as? [Int]) ?? [2, 3, 4, 5, 6])
        useFixedDays = d.bool(forKey: "useFixedDays")
        showWidget = d.bool(forKey: "showWidget")
    }
}

// MARK: - 计算

enum WorkStatus {
    case working, lunch, before, done, dayOff

    var title: String {
        switch self {
        case .working: return "在岗"
        case .lunch: return "午休"
        case .before: return "未上班"
        case .done: return "已下班"
        case .dayOff: return "休息日"
        }
    }

    var color: Color {
        switch self {
        case .working: return Color(red: 0.25, green: 0.9, blue: 0.4)
        case .lunch: return .orange
        case .before: return .gray
        case .done: return Color(red: 0.4, green: 0.7, blue: 1.0)
        case .dayOff: return .purple
        }
    }
}

struct Snapshot {
    var today: Double = 0
    var perSecond: Double = 0
    var hourly: Double = 0
    var daily: Double = 0
    var workedSeconds: Double = 0
    var progress: Double = 0
    var countdownLabel = ""
    var month: Double = 0
    var remainingDays = 0
    var totalWorkdays = 0
    var monthProgress: Double = 0
    var status: WorkStatus = .before
    var slogan = ""

    static func compute(now: Date, s: Settings) -> Snapshot {
        var snap = Snapshot()
        let cal = Calendar.current

        let st = Double(s.startMinutes * 60)
        let en = Double(s.endMinutes * 60)
        let ls = Double(s.lunchStart * 60)
        let le = Double(s.lunchEnd * 60)
        func lunchOverlap(_ a: Double, _ b: Double) -> Double {
            guard s.lunchEnabled else { return 0 }
            return max(0, min(b, le) - max(a, ls))
        }
        let total = (en - st) - lunchOverlap(st, en)
        guard total > 0 else {
            snap.slogan = "请在设置里检查上下班时间"
            return snap
        }

        // 本月工作日统计
        let day = cal.component(.day, from: now)
        let daysInMonth = cal.range(of: .day, in: .month, for: now)!.count
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        var passed = 0, remaining = 0, totalWorkdays = 0
        for i in 1...daysInMonth {
            let date = cal.date(byAdding: .day, value: i - 1, to: monthStart)!
            guard s.workdays.contains(cal.component(.weekday, from: date)) else { continue }
            totalWorkdays += 1
            if i < day { passed += 1 } else if i > day { remaining += 1 }
        }

        let base = s.useFixedDays ? 21.75 : Double(max(totalWorkdays, 1))
        snap.daily = s.monthlySalary / base
        snap.hourly = snap.daily / (total / 3600)
        snap.perSecond = snap.hourly / 3600
        snap.remainingDays = remaining
        snap.totalWorkdays = totalWorkdays

        // 今日进度
        let comps = cal.dateComponents([.hour, .minute, .second, .nanosecond], from: now)
        let t = Double(comps.hour! * 3600 + comps.minute! * 60 + comps.second!) + Double(comps.nanosecond!) / 1e9
        let isWorkday = s.workdays.contains(cal.component(.weekday, from: now))

        if isWorkday {
            let clamped = min(max(t, st), en)
            snap.workedSeconds = (clamped - st) - lunchOverlap(st, clamped)
            snap.progress = snap.workedSeconds / total
            if t < st { snap.status = .before }
            else if t >= en { snap.status = .done }
            else if s.lunchEnabled && t >= ls && t < le { snap.status = .lunch }
            else { snap.status = .working }
        } else {
            snap.status = .dayOff
        }
        snap.today = snap.daily * snap.progress
        snap.monthProgress = totalWorkdays > 0 ? (Double(passed) + snap.progress) / Double(totalWorkdays) : 0
        snap.month = snap.daily * Double(passed) + snap.today

        switch snap.status {
        case .working, .lunch: snap.countdownLabel = "距下班 " + hms(en - t)
        case .before: snap.countdownLabel = "距上班 " + hms(st - t)
        case .done: snap.countdownLabel = "已下班"
        case .dayOff: snap.countdownLabel = "今天休息"
        }

        snap.slogan = slogan(snap)
        return snap
    }

    private static func slogan(_ s: Snapshot) -> String {
        switch s.status {
        case .dayOff: return "休息日，钱在梦里慢慢涨"
        case .before: return "还没开工，先吃个早饭"
        case .done: return "下班！今天的钱已全部到手"
        case .lunch: return "午休时间，吃饱再战"
        case .working:
            switch s.progress {
            case ..<0.1: return "新的一天，先泡杯咖啡"
            case ..<0.3: return "刚进入状态，慢慢来"
            case ..<0.5: return "稳住，钱在一秒一秒进账"
            case ..<0.7: return "过半了，坚持住"
            case ..<0.9: return "收尾阶段，别硬熬"
            default: return "马上下班，收拾收拾"
            }
        }
    }
}

func hms(_ seconds: Double) -> String {
    let x = max(0, Int(seconds))
    return String(format: "%02d:%02d:%02d", x / 3600, x % 3600 / 60, x % 60)
}

func money(_ v: Double, _ digits: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumFractionDigits = digits
    f.maximumFractionDigits = digits
    return "¥" + (f.string(from: NSNumber(value: v)) ?? "0")
}

// MARK: - 时钟

final class Clock: ObservableObject {
    static let shared = Clock()
    @Published var now = Date()
    private var timer: Timer?

    private init() {
        timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.now = Date() }
        RunLoop.main.add(timer!, forMode: .common)
    }
}

// MARK: - 悬浮窗视图

let accentGreen = Color(red: 0.25, green: 0.92, blue: 0.35)

struct WidgetView: View {
    @ObservedObject var clock = Clock.shared
    @ObservedObject var settings = Settings.shared

    var body: some View {
        let s = Snapshot.compute(now: clock.now, s: settings)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日已赚").font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.7))
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(s.status.color).frame(width: 6, height: 6)
                    Text(s.status.title).font(.system(size: 12, weight: .semibold)).foregroundColor(s.status.color)
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(s.status.color.opacity(0.18)))
            }

            Text(money(s.today, 3))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(accentGreen)
                .shadow(color: accentGreen.opacity(0.35), radius: 8)
                .lineLimit(1).minimumScaleFactor(0.5)

            Divider().overlay(Color.white.opacity(0.1))

            HStack(alignment: .top) {
                stat("每秒进账", money(s.perSecond, 4))
                Spacer()
                stat("时薪", money(s.hourly, 2))
                Spacer()
                stat("日薪", money(s.daily, 2))
            }

            Divider().overlay(Color.white.opacity(0.1))

            HStack {
                Text("已工作 " + hms(s.workedSeconds))
                Spacer()
                Text("\(Int(s.progress * 100))%")
                Spacer()
                Text(s.countdownLabel).foregroundColor(accentGreen)
            }
            .font(.system(size: 13, weight: .medium)).monospacedDigit()
            .foregroundColor(.white.opacity(0.85))

            progressBar(s.progress, colors: [accentGreen, .yellow], height: 7)

            HStack {
                Text("本月已赚 " + money(s.month, 2))
                Spacer()
                Text(String(format: "%.1f%%", s.monthProgress * 100))
                Spacer()
                Text("还剩 \(s.remainingDays) 个工作日")
            }
            .font(.system(size: 12)).monospacedDigit()
            .foregroundColor(.white.opacity(0.7))

            progressBar(s.monthProgress, colors: [Color(red: 0.3, green: 0.65, blue: 1.0), Color(red: 0.7, green: 0.45, blue: 1.0)], height: 5)

            Text(s.slogan)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.55))
                .frame(maxWidth: .infinity)
        }
        .padding(18)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.17), Color(red: 0.08, green: 0.1, blue: 0.13)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .opacity(0.94)
        )
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08)))
        .contextMenu {
            Button("设置…") { AppDelegate.shared.openSettings() }
            Button("隐藏悬浮窗") { Settings.shared.showWidget = false }
            Divider()
            Button("退出") { NSApp.terminate(nil) }
        }
    }

    private func progressBar(_ value: Double, colors: [Color], height: CGFloat) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, g.size.width * min(value, 1)))
            }
        }
        .frame(height: height)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
            Text(value).font(.system(size: 18, weight: .semibold, design: .rounded)).monospacedDigit().foregroundColor(.white)
        }
    }
}

// MARK: - 设置视图

struct SettingsView: View {
    @ObservedObject var s = Settings.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    private let weekdayNames = [(2, "一"), (3, "二"), (4, "三"), (5, "四"), (6, "五"), (7, "六"), (1, "日")]

    private func timeBinding(_ kp: ReferenceWritableKeyPath<Settings, Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(Double(s[keyPath: kp] * 60)) },
            set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); s[keyPath: kp] = c.hour! * 60 + c.minute! }
        )
    }

    var body: some View {
        let snap = Snapshot.compute(now: Date(), s: s)
        Form {
            Section("薪资") {
                TextField("月薪 (¥)", value: $s.monthlySalary, format: .number)
                Picker("日薪计算", selection: $s.useFixedDays) {
                    Text("月薪 ÷ 21.75 天").tag(true)
                    Text("月薪 ÷ 本月实际工作日").tag(false)
                }
                LabeledContent("日薪 / 时薪", value: "\(money(snap.daily, 2)) / \(money(snap.hourly, 2))")
            }
            Section("工作时间") {
                DatePicker("上班", selection: timeBinding(\.startMinutes), displayedComponents: .hourAndMinute)
                DatePicker("下班", selection: timeBinding(\.endMinutes), displayedComponents: .hourAndMinute)
                Toggle("扣除午休", isOn: $s.lunchEnabled)
                if s.lunchEnabled {
                    DatePicker("午休开始", selection: timeBinding(\.lunchStart), displayedComponents: .hourAndMinute)
                    DatePicker("午休结束", selection: timeBinding(\.lunchEnd), displayedComponents: .hourAndMinute)
                }
                HStack {
                    Text("工作日")
                    Spacer()
                    ForEach(weekdayNames, id: \.0) { day, name in
                        Toggle(name, isOn: Binding(
                            get: { s.workdays.contains(day) },
                            set: { if $0 { s.workdays.insert(day) } else { s.workdays.remove(day) } }
                        ))
                        .toggleStyle(.button)
                    }
                }
            }
            Section("其他") {
                Toggle("显示桌面悬浮窗", isOn: $s.showWidget)
                Toggle("开机自动启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize()
    }
}

// MARK: - 窗口 & App

final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()
    private var panel: NSPanel!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var toggleItem: NSMenuItem!
    private var timer: Timer?
    private var observer: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPanel()
        setupStatusItem()
        observer = Settings.shared.$showWidget.sink { [weak self] show in
            DispatchQueue.main.async { self?.applyWidgetVisibility(show) }
        }
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.updateStatusTitle() }
        RunLoop.main.add(timer!, forMode: .common)
        updateStatusTitle()
    }

    /// 应用已在运行时再次双击打开，弹出设置窗口
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    private func setupPanel() {
        let host = DraggableHostingView(rootView: WidgetView())
        host.frame.size = host.fittingSize
        panel = NSPanel(contentRect: host.frame, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        if !panel.setFrameUsingName("SalaryWidget"), let screen = NSScreen.main {
            let v = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: v.maxX - host.frame.width - 24, y: v.maxY - host.frame.height - 24))
        }
        panel.setFrameAutosaveName("SalaryWidget")
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        toggleItem = NSMenuItem(title: "隐藏悬浮窗", action: #selector(toggleWidget), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func updateStatusTitle() {
        let snap = Snapshot.compute(now: Date(), s: Settings.shared)
        statusItem.button?.attributedTitle = NSAttributedString(
            string: "💰 " + money(snap.month, 2),
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)]
        )
        statusItem.button?.toolTip = "今日已赚 \(money(snap.today, 2))  ·  本月已赚 \(money(snap.month, 2))"
    }

    private func applyWidgetVisibility(_ show: Bool) {
        if show { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
        toggleItem.title = show ? "隐藏悬浮窗" : "显示悬浮窗"
    }

    @objc private func toggleWidget() { Settings.shared.showWidget.toggle() }

    @objc func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "工资计时器 设置"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.delegate = AppDelegate.shared
app.run()
