import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

extension KeyboardShortcuts.Name {
    static let startStopTimer = Self("startStopTimer")
}

private struct IntervalsView: View {
    @EnvironmentObject var timer: TBTimer
    private var minStr = NSLocalizedString("IntervalsView.min", comment: "min")

    var body: some View {
        VStack {
            Stepper(value: $timer.workIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.workIntervalLength.label",
                                           comment: "Work interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, timer.workIntervalLength))
                }
            }
            Stepper(value: $timer.shortRestIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.shortRestIntervalLength.label",
                                           comment: "Short rest interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, timer.shortRestIntervalLength))
                }
            }
            Stepper(value: $timer.longRestIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.longRestIntervalLength.label",
                                           comment: "Long rest interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, timer.longRestIntervalLength))
                }
            }
            .help(NSLocalizedString("IntervalsView.longRestIntervalLength.help",
                                    comment: "Long rest interval hint"))
            Stepper(value: $timer.workIntervalsInSet, in: 1 ... 10) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.workIntervalsInSet.label",
                                           comment: "Work intervals in a set label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(timer.workIntervalsInSet)")
                }
            }
            .help(NSLocalizedString("IntervalsView.workIntervalsInSet.help",
                                    comment: "Work intervals in set hint"))
            Spacer().frame(minHeight: 0)
        }
        .padding(4)
    }
}

private struct SettingsView: View {
    @EnvironmentObject var timer: TBTimer
    @ObservedObject private var launchAtLogin = LaunchAtLogin.observable

    var body: some View {
        VStack {
            KeyboardShortcuts.Recorder(for: .startStopTimer) {
                Text(NSLocalizedString("SettingsView.shortcut.label",
                                       comment: "Shortcut label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Toggle(isOn: $timer.stopAfterBreak) {
                Text(NSLocalizedString("SettingsView.stopAfterBreak.label",
                                       comment: "Stop after break label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
            Toggle(isOn: $timer.showTimerInMenuBar) {
                Text(NSLocalizedString("SettingsView.showTimerInMenuBar.label",
                                       comment: "Show timer in menu bar label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
                .onChange(of: timer.showTimerInMenuBar) { _ in
                    timer.updateTimeLeft()
                }
            Toggle(isOn: $launchAtLogin.isEnabled) {
                Text(NSLocalizedString("SettingsView.launchAtLogin.label",
                                       comment: "Launch at login label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
            Spacer().frame(minHeight: 0)
        }
        .padding(4)
    }
}

private struct VolumeSlider: View {
    @Binding var volume: Double

    var body: some View {
        Slider(value: $volume, in: 0...2) {
            Text(String(format: "%.1f", volume))
        }.gesture(TapGesture(count: 2).onEnded({
            volume = 1.0
        }))
    }
}

private struct SoundsView: View {
    @EnvironmentObject var player: TBPlayer

    private var columns = [
        GridItem(.flexible()),
        GridItem(.fixed(110))
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            Text(NSLocalizedString("SoundsView.isWindupEnabled.label",
                                   comment: "Windup label"))
            VolumeSlider(volume: $player.windupVolume)
            Text(NSLocalizedString("SoundsView.isDingEnabled.label",
                                   comment: "Ding label"))
            VolumeSlider(volume: $player.dingVolume)
            Text(NSLocalizedString("SoundsView.isTickingEnabled.label",
                                   comment: "Ticking label"))
            VolumeSlider(volume: $player.tickingVolume)
        }.padding(4)
        Spacer().frame(minHeight: 0)
    }
}

private enum ChildView {
    case timer, intervals, settings, sounds, stats
}

struct TBPopoverView: View {
    @ObservedObject var timer = TBTimer()
    @State private var buttonHovered = false
    @State private var activeChildView = ChildView.intervals

    private var startLabel = NSLocalizedString("TBPopoverView.start.label", comment: "Start label")
    private var stopLabel = NSLocalizedString("TBPopoverView.stop.label", comment: "Stop label")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                timer.startStop()
                TBStatusItem.shared.closePopover(nil)
            } label: {
                Text(timer.timer != nil ?
                     (buttonHovered ? stopLabel : timer.timeLeftString) :
                        startLabel)
                    /*
                      When appearance is set to "Dark" and accent color is set to "Graphite"
                      "defaultAction" button label's color is set to the same color as the
                      button, making the button look blank. #24
                     */
                    .foregroundColor(Color.white)
                    .font(.system(.body).monospacedDigit())
                    .frame(maxWidth: .infinity)
            }
            .onHover { over in
                buttonHovered = over
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            Picker("", selection: $activeChildView) {
                Text(NSLocalizedString("TBPopoverView.timer.label", comment: "Timer label")).tag(ChildView.timer)
                Text(NSLocalizedString("TBPopoverView.intervals.label",
                                       comment: "Intervals label")).tag(ChildView.intervals)
                Text(NSLocalizedString("TBPopoverView.settings.label",
                                       comment: "Settings label")).tag(ChildView.settings)
                Text(NSLocalizedString("TBPopoverView.sounds.label",
                                       comment: "Sounds label")).tag(ChildView.sounds)
                Text(NSLocalizedString("TBPopoverView.stats.label",
                                       comment: "Stats label")).tag(ChildView.stats)
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .pickerStyle(.segmented)

            GroupBox {
                switch activeChildView {
                case .timer:
                    TimerView().environmentObject(timer)
                case .intervals:
                    IntervalsView().environmentObject(timer)
                case .settings:
                    SettingsView().environmentObject(timer)
                case .sounds:
                    SoundsView().environmentObject(timer.player)
                case .stats:
                    StatsView()
                }
            }

            Group {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.orderFrontStandardAboutPanel()
                } label: {
                    Text(NSLocalizedString("TBPopoverView.about.label",
                                           comment: "About label"))
                    Spacer()
                    Text("⌘ A").foregroundColor(Color.gray)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("a")
                Button {
                    NSApplication.shared.terminate(self)
                } label: {
                    Text(NSLocalizedString("TBPopoverView.quit.label",
                                           comment: "Quit label"))
                    Spacer()
                    Text("⌘ Q").foregroundColor(Color.gray)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
            }
        }
        #if DEBUG
            /*
             After several hours of Googling and trying various StackOverflow
             recipes I still haven't figured a reliable way to auto resize
             popover to fit all it's contents (pull requests are welcome!).
             The following code block is used to determine the optimal
             geometry of the popover.
             */
            .overlay(
                GeometryReader { proxy in
                    debugSize(proxy: proxy)
                }
            )
        #endif
            /* Use values from GeometryReader */
//            .frame(width: 240, height: 276)
            .padding(12)
            .frame(width: 260, height: 360)
    }
}

#if DEBUG
    func debugSize(proxy: GeometryProxy) -> some View {
        print("Optimal popover size:", proxy.size)
        return Color.clear
    }
#endif

// 计时器主视图结构体
private struct TimerView: View {
    @EnvironmentObject private var timer: TBTimer
    private let accentGreen = Color(red: 0.36, green: 0.71, blue: 0.36)
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 4)
            StatusIndicator(state: getCurrentState(), accentGreen: accentGreen)

            ZStack {
                CircularProgressRing(
                    progress: progressValue,
                    ringColor: getCurrentStateColor()
                )
                VStack(spacing: 4) {
                    Text(timer.timeLeftString)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
            .frame(height: 128)

            SetProgressDots(current: timer.consecutiveWorkIntervals,
                            total: timer.workIntervalsInSet)
            Spacer(minLength: 4)
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // 获取当前状态
    private func getCurrentState() -> TBStateMachineStates {
        return timer.stateMachine.state
    }
    
    // 根据当前状态获取颜色
    private func getCurrentStateColor() -> Color {
        switch getCurrentState() {
        case .work:
            return Color.red // 专注模式使用番茄红
        case .rest:
            return accentGreen // 休息模式使用图标绿色
        case .idle:
            return Color.gray // 空闲状态使用灰色
        }
    }

    private var progressValue: Double {
        guard timer.currentIntervalSeconds > 0 else { return 0 }
        let elapsed = max(0, timer.currentIntervalSeconds - timer.timeLeftSeconds)
        return min(1.0, Double(elapsed) / Double(timer.currentIntervalSeconds))
    }

    private func getStateSubtitle() -> String {
        switch getCurrentState() {
        case .work:
            return "专注倒计时"
        case .rest:
            return "休息倒计时"
        case .idle:
            return "点击开始"
        }
    }
    
    // 状态指示器组件
    private struct StatusIndicator: View {
        let state: TBStateMachineStates
        let accentGreen: Color
        
        var body: some View {
            Text(getStateText())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(getStateColor())
        }
        
        private func getStateText() -> String {
            switch state {
            case .work:
                return "专注中"
            case .rest:
                return "休息中"
            case .idle:
                return "准备开始"
            }
        }
        
        private func getStateColor() -> Color {
            switch state {
            case .work:
                return Color.red
            case .rest:
                return accentGreen
            case .idle:
                return Color.gray
            }
        }
    }
    
    // 圆环进度
    private struct CircularProgressRing: View {
        let progress: Double
        let ringColor: Color

        var body: some View {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.2), value: progress)
            }
        }
    }

    // 组内进度点
    private struct SetProgressDots: View {
        let current: Int
        let total: Int
        
        var body: some View {
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { index in
                    if index < current {
                        Image("Fanqie")
                            .resizable()
                            .renderingMode(.original)
                            .frame(width: 12, height: 12)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.25))
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
    }
}
