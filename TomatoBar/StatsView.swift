import SwiftUI

// MARK: - 统计视图主体
struct StatsView: View {
    @StateObject private var statsManager = TBStatsManager()
    @State private var currentWeekStart: Date
    @State private var currentMonthStart: Date
    @State private var hoveredCell: TBStatsCell?
    @State private var hoveredDayCell: TBStatsDayCell?
    @State private var viewMode: StatsViewMode = .week
    @State private var chartMode: StatsChartMode = .heatmap
    @State private var selectedMonthDayIndex: Int?
    @State private var hoveredMonthDayIndex: Int?
    @State private var hoveredWeekDayIndex: Int?
    @State private var hoverWorkItem: DispatchWorkItem?
    @State private var lastHoveredDayId: UUID?
    
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "M月d日"
        return formatter
    }()
    
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    private let accentColor = Color(red: 0.36, green: 0.71, blue: 0.36)

    init() {
        let manager = TBStatsManager()
        _currentWeekStart = State(initialValue: manager.getCurrentWeekStart())
        _currentMonthStart = State(initialValue: manager.getCurrentMonthStart())
    }

    private var weekStats: TBWeekStats {
        statsManager.getWeekStats(for: currentWeekStart)
    }

    private var monthStats: TBMonthStats {
        statsManager.getMonthStats(for: currentMonthStart)
    }

    private var displayInfo: (title: String, duration: String, label: String) {
        switch viewMode {
        case .week:
            if let cell = hoveredCell {
                return (weekStats.weekRange, cell.formattedDuration, cell.detailDescription)
            }
            if let index = hoveredWeekDayIndex {
                let calendar = Calendar.current
                if let date = calendar.date(byAdding: .day, value: index, to: currentWeekStart) {
                    let duration = weekBarValues.indices.contains(index) ? weekBarValues[index] : 0
                    let formatted = TBStatsDayCell(date: date, duration: duration, isInCurrentMonth: true).formattedDuration
                    let weekday = Self.weekdayFormatter.string(from: date)
                    return (weekStats.weekRange, formatted, "\(weekday) · 日统计")
                }
            }
            return (weekStats.weekRange, weekStats.formattedTotalDuration, "本周总计")
        case .month:
            if let cell = hoveredDayCell {
                let dayTitle = Self.dayFormatter.string(from: cell.date)
                return (monthStats.monthTitle, cell.formattedDuration, "\(dayTitle) · 日统计")
            }
            if let index = hoveredMonthDayIndex,
               let date = Calendar.current.date(byAdding: .day, value: index, to: currentMonthStart) {
                let dayTitle = Self.dayFormatter.string(from: date)
                let duration = monthBarValues.indices.contains(index) ? monthBarValues[index] : 0
                let formatted = TBStatsDayCell(date: date, duration: duration, isInCurrentMonth: true).formattedDuration
                return (monthStats.monthTitle, formatted, "\(dayTitle) · 日统计")
            }
            if let index = selectedMonthDayIndex,
               let date = Calendar.current.date(byAdding: .day, value: index, to: currentMonthStart) {
                let dayTitle = Self.dayFormatter.string(from: date)
                let duration = monthBarValues.indices.contains(index) ? monthBarValues[index] : 0
                let formatted = TBStatsDayCell(date: date, duration: duration, isInCurrentMonth: true).formattedDuration
                return (monthStats.monthTitle, formatted, "\(dayTitle) · 日统计")
            }
            return (monthStats.monthTitle, monthStats.formattedTotalDuration, "本月总计")
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            StatsNavigationBar(
                title: displayInfo.title,
                mode: viewMode,
                accentColor: accentColor,
                isCurrent: isCurrentPeriod,
                onPrevious: { navigate(by: -1) },
                onNext: { navigate(by: 1) },
                onSelectMode: { viewMode = $0 }
            )

            StatsDisplayPanel(
                duration: displayInfo.duration,
                label: displayInfo.label
            )

            StatsChartToggle(
                selection: $chartMode,
                accentColor: accentColor
            )

            Group {
                if chartMode == .heatmap {
                    heatmapView
                } else {
                    barChartView
                }
            }
            .frame(height: chartHeight, alignment: .top)

        }
        .padding(.bottom, 6)
        .onAppear {
            statsManager.loadRecords()
        }
    }

    private var heatmapView: some View {
        Group {
            switch viewMode {
            case .week:
                StatsHeatmap(
                    cells: weekStats.cells,
                    hoveredCell: $hoveredCell,
                    accentColor: accentColor,
                    today: Date(),
                    currentPeriod: TBPeriod.getPeriod(from: Date())
                )
            case .month:
                StatsMonthHeatmap(
                    cells: monthStats.cells,
                    hoveredCell: $hoveredDayCell,
                    accentColor: accentColor,
                    today: Date(),
                    onHover: { cell in
                        handleMonthHover(cell)
                    }
                )
            }
        }
    }

    private var barChartView: some View {
        Group {
            switch viewMode {
            case .week:
                StatsBarChart(
                    values: weekBarValues,
                    labels: TBStatsManager.weekdayLabels,
                    accentColor: accentColor,
                    showLabels: true,
                    onSelect: nil,
                    onHover: { index in
                        hoveredWeekDayIndex = index
                    },
                    highlightIndex: currentWeekTodayIndex
                )
            case .month:
                StatsBarChart(
                    values: monthBarValues,
                    labels: monthDayLabels,
                    accentColor: accentColor,
                    showLabels: false,
                    onSelect: { index in
                        selectedMonthDayIndex = index
                    },
                    onHover: { index in
                        hoveredMonthDayIndex = index
                    },
                    highlightIndex: currentMonthTodayIndex
                )
            }
        }
    }

    private var weekBarValues: [Int] {
        var totals: [Int] = Array(repeating: 0, count: 7)
        for cell in weekStats.cells {
            let dayIndex = Calendar.current.component(.weekday, from: cell.date)
            let index = (dayIndex + 5) % 7
            totals[index] += cell.duration
        }
        return totals
    }

    private var monthBarValues: [Int] {
        var totals: [Int] = []
        let calendar = Calendar.current
        let monthRange = calendar.range(of: .day, in: .month, for: currentMonthStart) ?? 1..<1
        for day in monthRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: currentMonthStart) else {
                totals.append(0)
                continue
            }
            let total = monthStats.cells
                .filter { $0.isInCurrentMonth && calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.duration }
            totals.append(total)
        }
        return totals
    }

    private var monthDayLabels: [String] {
        let calendar = Calendar.current
        let monthRange = calendar.range(of: .day, in: .month, for: currentMonthStart) ?? 1..<1
        return monthRange.map { "\($0)" }
    }

    private var isCurrentPeriod: Bool {
        switch viewMode {
        case .week:
            return statsManager.isCurrentWeek(currentWeekStart)
        case .month:
            return statsManager.isCurrentMonth(currentMonthStart)
        }
    }

    private var currentMonthTodayIndex: Int? {
        let calendar = Calendar.current
        let today = Date()
        guard calendar.isDate(today, equalTo: currentMonthStart, toGranularity: .month) else {
            return nil
        }
        return calendar.component(.day, from: today) - 1
    }

    private var currentWeekTodayIndex: Int? {
        let calendar = Calendar.current
        let today = Date()
        guard calendar.isDate(today, equalTo: currentWeekStart, toGranularity: .weekOfYear) else {
            return nil
        }
        let weekday = calendar.component(.weekday, from: today)
        return (weekday + 5) % 7
    }

    private var chartHeight: CGFloat {
        switch (viewMode, chartMode) {
        case (.month, .heatmap):
            return 124
        case (.month, .bars):
            return 110
        case (.week, .heatmap):
            return 110
        case (.week, .bars):
            return 110
        }
    }

    private func navigate(by offset: Int) {
        switch viewMode {
        case .week:
            if let newWeek = statsManager.offsetWeek(from: currentWeekStart, by: offset) {
                currentWeekStart = newWeek
            }
        case .month:
            if let newMonth = statsManager.offsetMonth(from: currentMonthStart, by: offset) {
                currentMonthStart = newMonth
            }
        }
        hoveredCell = nil
        hoveredDayCell = nil
        selectedMonthDayIndex = nil
        hoveredMonthDayIndex = nil
        hoveredWeekDayIndex = nil
        lastHoveredDayId = nil
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
    }

    private func handleMonthHover(_ cell: TBStatsDayCell?) {
        let targetId = cell?.id
        if targetId == lastHoveredDayId {
            return
        }
        hoverWorkItem?.cancel()
        let work = DispatchWorkItem {
            lastHoveredDayId = targetId
            hoveredDayCell = cell
        }
        hoverWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: work)
    }
}

// MARK: - 视图模式
private enum StatsViewMode: String, CaseIterable {
    case week = "周"
    case month = "月"
}

private enum StatsChartMode: String, CaseIterable {
    case heatmap = "热力图"
    case bars = "条形图"
}

// MARK: - 顶部导航
private struct StatsNavigationBar: View {
    let title: String
    let mode: StatsViewMode
    let accentColor: Color
    let isCurrent: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSelectMode: (StatsViewMode) -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .overlay(
            HStack(spacing: 6) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.caption2)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                Spacer()

                StatsModeInlineToggle(
                    selection: mode,
                    accentColor: accentColor,
                    onSelect: onSelectMode
                )

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(isCurrent ? .secondary : .primary)
                }
                .buttonStyle(.plain)
                .disabled(isCurrent)
            }
        )
    }
}

// MARK: - 数值显示面板
private struct StatsDisplayPanel: View {
    let duration: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(duration)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .animation(.easeInOut(duration: 0.15), value: duration)

            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.secondary)
                .animation(.easeInOut(duration: 0.15), value: label)
        }
        .frame(height: 36)
    }
}

// MARK: - 紧凑切换
private struct StatsChartToggle: View {
    @Binding var selection: StatsChartMode
    let accentColor: Color

    var body: some View {
        HStack(spacing: 6) {
            chartButton(mode: .heatmap, systemName: "square.grid.3x3.fill")
            chartButton(mode: .bars, systemName: "chart.bar.fill")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.primary.opacity(0.06))
        .cornerRadius(6)
    }

    private func chartButton(mode: StatsChartMode, systemName: String) -> some View {
        Button {
            selection = mode
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(selection == mode ? accentColor : Color.secondary)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
    }
}

private struct StatsModeInlineToggle: View {
    let selection: StatsViewMode
    let accentColor: Color
    let onSelect: (StatsViewMode) -> Void

    var body: some View {
        HStack(spacing: 6) {
            modeButton(label: "本周", mode: .week)
            modeButton(label: "本月", mode: .month)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.primary.opacity(0.06))
        .cornerRadius(6)
    }

    private func modeButton(label: String, mode: StatsViewMode) -> some View {
        Button {
            onSelect(mode)
        } label: {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(selection == mode ? accentColor : Color.secondary)
                .padding(.vertical, 2)
                .overlay(
                    Rectangle()
                        .fill(selection == mode ? accentColor : Color.clear)
                        .frame(height: 1),
                    alignment: .bottom
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ToggleGroup: View {
    let items: [String]
    let selectionIndex: Int
    let accentColor: Color
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items.indices, id: \.self) { index in
                Button {
                    onSelect(index)
                } label: {
                    Text(items[index])
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(selectionIndex == index ? .white : .primary)
                        .frame(width: 40, height: 18)
                        .background(selectionIndex == index ? accentColor : Color.primary.opacity(0.08))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 周热力图
private struct StatsHeatmap: View {
    let cells: [TBStatsCell]
    @Binding var hoveredCell: TBStatsCell?
    let accentColor: Color
    let today: Date
    let currentPeriod: TBPeriod

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text("")
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 24)

                ForEach(TBStatsManager.weekdayLabels, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(Array(TBPeriod.allCases.enumerated()), id: \.offset) { periodIndex, period in
                HStack(spacing: 4) {
                    Text(period.localizedName.prefix(1))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.7))
                        .frame(width: 20, alignment: .center)

                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            let cellIndex = periodIndex * 7 + dayIndex
                            if cellIndex < cells.count {
                                let cell = cells[cellIndex]
                                let isToday = Calendar.current.isDate(cell.date, inSameDayAs: today)
                                let isCurrentPeriod = isToday && cell.period == currentPeriod
                                HeatmapCell(
                                    cell: cell,
                                    isHovered: hoveredCell?.id == cell.id,
                                    accentColor: accentColor,
                                    isToday: isToday,
                                    isCurrentPeriod: isCurrentPeriod
                                )
                                .contentShape(Rectangle())
                                .onHover { isHovering in
                                    hoveredCell = isHovering ? cell : nil
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 月热力图
private struct StatsMonthHeatmap: View {
    let cells: [TBStatsDayCell]
    @Binding var hoveredCell: TBStatsDayCell?
    let accentColor: Color
    let today: Date
    let onHover: (TBStatsDayCell?) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 0) {
                ForEach(TBStatsManager.weekdayLabels, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(cells) { cell in
                    MonthHeatmapCell(
                        cell: cell,
                        isHovered: hoveredCell?.id == cell.id,
                        accentColor: accentColor,
                        isToday: Calendar.current.isDate(cell.date, inSameDayAs: today)
                    )
                        .contentShape(Rectangle())
                        .onHover { isHovering in
                            onHover(isHovering ? cell : nil)
                        }
                }
            }
        }
    }
}

// MARK: - 年热力图
// MARK: - 热力图单元格
private struct HeatmapCell: View {
    let cell: TBStatsCell
    let isHovered: Bool
    let accentColor: Color
    let isToday: Bool
    let isCurrentPeriod: Bool

    private var fillColor: Color {
        if cell.isEmpty {
            return Color.primary.opacity(0.05)
        }
        return accentColor.opacity(0.2 + cell.intensity * 0.8)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(fillColor)
            .frame(height: 18)
            .overlay(
                RoundedRectangle(cornerRadius: 2.5)
                    .stroke(
                        isCurrentPeriod ? accentColor :
                            (isToday ? accentColor.opacity(0.6) :
                                (isHovered ? Color.primary : Color.clear)),
                        lineWidth: isCurrentPeriod ? 1.6 : (isToday ? 1.2 : 1.5)
                    )
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
    }
}

private struct MonthHeatmapCell: View {
    let cell: TBStatsDayCell
    let isHovered: Bool
    let accentColor: Color
    let isToday: Bool

    private var fillColor: Color {
        if !cell.isInCurrentMonth {
            return Color.clear
        }
        if cell.isEmpty {
            return Color.primary.opacity(0.05)
        }
        return accentColor.opacity(0.2 + cell.intensity * 0.8)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(fillColor)
            .frame(height: 16)
            .overlay(
                Text("\(cell.dayNumber)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(cell.isInCurrentMonth ? .primary.opacity(0.7) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        isToday ? accentColor :
                            (isHovered ? Color.primary : Color.clear),
                        lineWidth: isToday ? 1.4 : 1.2
                    )
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
            )
    }
}

// MARK: - 条形图
private struct StatsBarChart: View {
    let values: [Int]
    let labels: [String]
    let accentColor: Color
    let showLabels: Bool
    let onSelect: ((Int) -> Void)?
    let onHover: ((Int?) -> Void)?
    let highlightIndex: Int?

    private var maxValue: Int {
        max(values.max() ?? 1, 1)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    let height = CGFloat(value) / CGFloat(maxValue)
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accentColor.opacity(0.15))
                            .frame(height: 70)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accentColor.opacity(0.75))
                            .frame(height: max(4, 70 * height))
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(index == highlightIndex ? accentColor : Color.clear, lineWidth: 1.2)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect?(index)
                    }
                    .onHover { isHovering in
                        onHover?(isHovering ? index : nil)
                    }
                }
            }
            .frame(height: 70)

            if showLabels {
                HStack(spacing: 4) {
                    ForEach(labels.indices, id: \.self) { index in
                        Text(labels[index])
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

// MARK: - 图例说明
// MARK: - 预览
#if DEBUG
struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView()
            .frame(width: 240, height: 320)
            .padding()
    }
}
#endif
