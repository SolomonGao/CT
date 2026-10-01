import Foundation

// MARK: - 存储协议

/// 记录与目标的读写抽象。
/// - P1 由 InMemoryStore 实现（本文件，CLI/测试用）；
/// - iOS 侧由 SwiftDataStore 实现（Sources/MacroCore/iOS/SwiftDataModels.swift），
///   数据落在 App Group 共享容器，Widget 与 App 读写同一份数据。
public protocol MacroStore: Sendable {
    func addEntry(_ entry: FoodEntryRecord) async throws
    func deleteEntry(id: UUID) async throws
    func entries(from start: Date, to end: Date) async throws -> [FoodEntryRecord]
    func setGoal(_ goal: MacroGoal, for day: Date) async throws
    func goal(for day: Date) async throws -> MacroGoal?
}

// MARK: - 内存实现（开发/测试/CLI）

public actor InMemoryStore: MacroStore {
    private var entries: [FoodEntryRecord] = []
    private var goals: [Date: MacroGoal] = [:]
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func addEntry(_ entry: FoodEntryRecord) async throws {
        entries.append(entry)
    }

    public func deleteEntry(id: UUID) async throws {
        entries.removeAll { $0.id == id }
    }

    public func entries(from start: Date, to end: Date) async throws -> [FoodEntryRecord] {
        entries
            .filter { $0.timestamp >= start && $0.timestamp < end }
            .sorted { $0.timestamp < $1.timestamp }
    }

    public func setGoal(_ goal: MacroGoal, for day: Date) async throws {
        goals[calendar.startOfDay(for: day)] = goal
    }

    public func goal(for day: Date) async throws -> MacroGoal? {
        goals[calendar.startOfDay(for: day)]
    }
}

// MARK: - 进度聚合

/// 单项营养素进度，ratio 已按 0...1 截断，over 标记是否超出目标。
public struct MacroProgress: Equatable, Sendable {
    public var consumed: Double
    public var target: Double
    public var ratio: Double
    public var over: Bool
}

public struct MacroDayProgress: Equatable, Sendable {
    public var protein: MacroProgress
    public var carbs: MacroProgress
    public var fat: MacroProgress
}

public struct DaySummary: Equatable, Sendable {
    public var date: Date
    public var totals: MacroNutrients
    public var goal: MacroGoal?
    public var progress: MacroDayProgress
}

/// 纯函数聚合逻辑：App、Widget、测试共用，保证各处数字永远一致。
public enum IntakeAggregator {
    public static func totals(
        _ entries: [FoodEntryRecord],
        on day: Date,
        calendar: Calendar = .current
    ) -> MacroNutrients {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return .zero }
        return entries
            .filter { $0.timestamp >= start && $0.timestamp < end }
            .reduce(.zero) { $0 + $1.macros }
    }

    private static func makeProgress(consumed: Double, target: Double) -> MacroProgress {
        let ratio = target > 0 ? min(max(consumed / target, 0), 1) : 0
        return MacroProgress(
            consumed: consumed,
            target: target,
            ratio: ratio,
            over: target > 0 && consumed > target
        )
    }

    public static func progress(
        totals: MacroNutrients,
        goal: MacroGoal?
    ) -> MacroDayProgress {
        let g = goal ?? MacroGoal(proteinTarget: 0, carbsTarget: 0, fatTarget: 0)
        return MacroDayProgress(
            protein: makeProgress(consumed: totals.protein_g, target: g.proteinTarget),
            carbs: makeProgress(consumed: totals.carbs_g, target: g.carbsTarget),
            fat: makeProgress(consumed: totals.fat_g, target: g.fatTarget)
        )
    }

    /// 以 date 所在周的周一为起点列出 7 天（默认日历的 firstWeekday 之前回推到周一）。
    public static func weekDates(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let dayStart = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: dayStart) // 1=Sunday
        let daysSinceMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: dayStart)
        else { return [dayStart] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    public static func weeklySummary(
        entries: [FoodEntryRecord],
        goalFor: (Date) async throws -> MacroGoal?,
        around date: Date,
        calendar: Calendar = .current
    ) async rethrows -> [DaySummary] {
        var result: [DaySummary] = []
        for day in weekDates(containing: date, calendar: calendar) {
            let totals = totals(entries, on: day, calendar: calendar)
            let goal = try await goalFor(day)
            result.append(DaySummary(
                date: day,
                totals: totals,
                goal: goal,
                progress: progress(totals: totals, goal: goal)
            ))
        }
        return result
    }
}
