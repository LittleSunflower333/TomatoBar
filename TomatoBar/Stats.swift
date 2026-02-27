import Foundation
import SwiftUI

// MARK: - 记录类型
enum TBRecordType: String, Codable {
    case work, shortBreak, longBreak
}

// MARK: - 时段枚举
enum TBPeriod: String, Codable, CaseIterable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
    
    var localizedName: String {
        switch self {
        case .morning: return NSLocalizedString("Period.morning", value: "早晨", comment: "")
        case .afternoon: return NSLocalizedString("Period.afternoon", value: "下午", comment: "")
        case .evening: return NSLocalizedString("Period.evening", value: "晚上", comment: "")
        }
    }
    
    static func getPeriod(from date: Date) -> TBPeriod {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0..<12: return .morning      // 0:00 - 11:59 早晨
        case 12..<18: return .afternoon   // 12:00 - 17:59 下午
        default: return .evening          // 18:00 - 23:59 晚上
        }
    }
}

// MARK: - 番茄钟记录
struct TBTomatoRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let duration: Int
    let type: TBRecordType
    let period: TBPeriod
    
    init(timestamp: Date = Date(), duration: Int, type: TBRecordType = .work) {
        self.id = UUID()
        self.timestamp = timestamp
        self.duration = duration
        self.type = type
        self.period = TBPeriod.getPeriod(from: timestamp)
    }
}

// MARK: - 统计数据单元格
struct TBStatsCell: Identifiable {
    let id = UUID()
    let date: Date
    let period: TBPeriod
    let duration: Int
    
    // 缓存的 DateFormatter
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    var isEmpty: Bool { duration == 0 }
    
    var formattedDuration: String {
        let minutes = duration / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
    
    var detailDescription: String {
        let weekday = Self.dateFormatter.string(from: date)
        return "\(weekday) · \(period.localizedName.uppercased())"
    }
    
    // 计算颜色强度 (0-1)
    var intensity: Double {
        guard duration > 0 else { return 0 }
        // 1小时为最大值,超过则取1.0
        return min(Double(duration) / 3600.0, 1.0)
    }
}

// MARK: - 周统计数据
struct TBWeekStats {
    let weekStart: Date
    let cells: [TBStatsCell]
    let totalDuration: Int
    
    // 缓存的 DateFormatter
    private static let weekRangeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "M月d日"
        return formatter
    }()
    
    var weekRange: String {
        let calendar = Calendar.current
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return ""
        }
        return "\(Self.weekRangeFormatter.string(from: weekStart)) - \(Self.weekRangeFormatter.string(from: weekEnd))"
    }
    
    var formattedTotalDuration: String {
        let minutes = totalDuration / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - 月统计数据
struct TBMonthStats {
    let monthStart: Date
    let cells: [TBStatsDayCell]
    let totalDuration: Int

    private static let monthTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    var monthTitle: String {
        Self.monthTitleFormatter.string(from: monthStart)
    }

    var formattedTotalDuration: String {
        let minutes = totalDuration / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - 年统计数据
struct TBYearStats {
    let yearStart: Date
    let monthlyTotals: [Int] // 12 months

    private static let yearTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy年"
        return formatter
    }()

    var yearTitle: String {
        Self.yearTitleFormatter.string(from: yearStart)
    }

    var totalDuration: Int {
        monthlyTotals.reduce(0, +)
    }

    var formattedTotalDuration: String {
        let minutes = totalDuration / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - 日统计单元格
struct TBStatsDayCell: Identifiable {
    let id = UUID()
    let date: Date
    let duration: Int
    let isInCurrentMonth: Bool

    var isEmpty: Bool { duration == 0 }

    var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var formattedDuration: String {
        let minutes = duration / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    var intensity: Double {
        guard duration > 0 else { return 0 }
        return min(Double(duration) / 3600.0, 1.0)
    }
}

// MARK: - 统计管理器
class TBStatsManager: ObservableObject {
    private let storageKey = "TomatoBarStats"
    @Published private(set) var records: [TBTomatoRecord] = []
    
    // 中文星期标签
    static let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]
    
    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // 周一为第一天
        return cal
    }()
    
    init() {
        loadRecords()
    }
    
    // MARK: - 数据持久化
    func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TBTomatoRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded
    }
    
    private func saveRecords() {
        guard let encoded = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }
    
    func addRecord(duration: Int, type: TBRecordType = .work, timestamp: Date = Date()) {
        let record = TBTomatoRecord(timestamp: timestamp, duration: duration, type: type)
        records.append(record)
        saveRecords()
        objectWillChange.send()
    }
    
    // 兼容旧API
    func addTomatoRecord(duration: Int) {
        addRecord(duration: duration, type: .work)
    }
    
    // MARK: - 统计数据生成
    
    /// 获取指定周的统计数据 (3行 x 7列 = 21个格子)
    func getWeekStats(for weekStart: Date) -> TBWeekStats {
        let workRecords = records.filter { $0.type == .work }
        var cells: [TBStatsCell] = []
        
        // 按时段-日期顺序生成格子 (确保LazyVGrid按行填充)
        for period in TBPeriod.allCases {
            for dayOffset in 0..<7 {
                guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else {
                    continue
                }
                
                let dayDuration = workRecords
                    .filter { calendar.isDate($0.timestamp, inSameDayAs: targetDate) && $0.period == period }
                    .reduce(0) { $0 + $1.duration }
                
                let cell = TBStatsCell(date: targetDate, period: period, duration: dayDuration)
                cells.append(cell)
            }
        }
        
        let totalDuration = cells.reduce(0) { $0 + $1.duration }
        return TBWeekStats(weekStart: weekStart, cells: cells, totalDuration: totalDuration)
    }

    /// 获取指定月统计数据（按周排布 6行 x 7列）
    func getMonthStats(for monthStart: Date) -> TBMonthStats {
        let workRecords = records.filter { $0.type == .work }
        let calendar = calendar

        guard let monthRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return TBMonthStats(monthStart: monthStart, cells: [], totalDuration: 0)
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmpty = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [TBStatsDayCell] = []
        let totalCells = 42

        for index in 0..<totalCells {
            let dayOffset = index - leadingEmpty
            if dayOffset < 0 {
                let date = calendar.date(byAdding: .day, value: dayOffset, to: monthStart) ?? monthStart
                cells.append(TBStatsDayCell(date: date, duration: 0, isInCurrentMonth: false))
                continue
            }
            let dayNumber = dayOffset + 1
            if !monthRange.contains(dayNumber) {
                let date = calendar.date(byAdding: .day, value: dayOffset, to: monthStart) ?? monthStart
                cells.append(TBStatsDayCell(date: date, duration: 0, isInCurrentMonth: false))
                continue
            }

            let date = calendar.date(byAdding: .day, value: dayOffset, to: monthStart) ?? monthStart
            let dayDuration = workRecords
                .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
                .reduce(0) { $0 + $1.duration }
            cells.append(TBStatsDayCell(date: date, duration: dayDuration, isInCurrentMonth: true))
        }

        let totalDuration = cells.reduce(0) { $0 + $1.duration }
        return TBMonthStats(monthStart: monthStart, cells: cells, totalDuration: totalDuration)
    }

    /// 获取指定年统计数据（12个月总计）
    func getYearStats(for yearStart: Date) -> TBYearStats {
        let workRecords = records.filter { $0.type == .work }
        var monthlyTotals: [Int] = Array(repeating: 0, count: 12)

        for month in 0..<12 {
            guard let monthDate = calendar.date(byAdding: .month, value: month, to: yearStart) else {
                continue
            }
            let total = workRecords
                .filter { calendar.isDate($0.timestamp, equalTo: monthDate, toGranularity: .month) }
                .reduce(0) { $0 + $1.duration }
            monthlyTotals[month] = total
        }

        return TBYearStats(yearStart: yearStart, monthlyTotals: monthlyTotals)
    }
    
    /// 获取今日统计
    func getTodayStats() -> (duration: String, label: String) {
        let today = Date()
        let todayDuration = records
            .filter { $0.type == .work && calendar.isDate($0.timestamp, inSameDayAs: today) }
            .reduce(0) { $0 + $1.duration }
        
        let minutes = todayDuration / 60
        let durationString: String
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            durationString = remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        } else {
            durationString = "\(minutes)m"
        }
        
        // 使用静态 formatter 避免重复创建
        let dateString = Self.todayDateFormatter.string(from: today)
        
        return (durationString, "\(dateString) · " + NSLocalizedString("Stats.todayTotal", value: "今日总计", comment: ""))
    }
    
    // 缓存的 DateFormatter
    private static let todayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "M月d日"
        return formatter
    }()
    
    // MARK: - 日期辅助方法
    
    func getCurrentWeekStart() -> Date {
        let now = Date()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return calendar.date(from: components) ?? now
    }

    func getCurrentMonthStart() -> Date {
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        return calendar.date(from: components) ?? now
    }

    func getCurrentYearStart() -> Date {
        let now = Date()
        let components = calendar.dateComponents([.year], from: now)
        return calendar.date(from: components) ?? now
    }
    
    func offsetWeek(from weekStart: Date, by weeks: Int) -> Date? {
        calendar.date(byAdding: .weekOfYear, value: weeks, to: weekStart)
    }

    func offsetMonth(from monthStart: Date, by months: Int) -> Date? {
        calendar.date(byAdding: .month, value: months, to: monthStart)
    }

    func offsetYear(from yearStart: Date, by years: Int) -> Date? {
        calendar.date(byAdding: .year, value: years, to: yearStart)
    }
    
    func isCurrentWeek(_ weekStart: Date) -> Bool {
        calendar.isDate(weekStart, equalTo: getCurrentWeekStart(), toGranularity: .weekOfYear)
    }

    func isCurrentMonth(_ monthStart: Date) -> Bool {
        calendar.isDate(monthStart, equalTo: getCurrentMonthStart(), toGranularity: .month)
    }

    func isCurrentYear(_ yearStart: Date) -> Bool {
        calendar.isDate(yearStart, equalTo: getCurrentYearStart(), toGranularity: .year)
    }
}
