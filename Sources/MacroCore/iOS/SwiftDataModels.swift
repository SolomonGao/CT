// iOS-only：SwiftData 持久层 + 共享容器 + 当日快照加载。
// 本文件仅在 iOS 编译（#if canImport(UIKit) 保护），Windows/CLI 构建时为空。
// 数据落在 App Group 共享容器：App 与 Widget Extension 读写同一份数据。

#if canImport(UIKit)
import Foundation
import SwiftData

// MARK: - SwiftData 实体

@Model
final class FoodEntryEntity {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var name: String
    var protein_g: Double
    var carbs_g: Double
    var fat_g: Double
    var sourceRaw: String
    var provider: String?
    var aiConfidence: Double?

    init(record: FoodEntryRecord) {
        self.id = record.id
        self.timestamp = record.timestamp
        self.name = record.name
        self.protein_g = record.macros.protein_g
        self.carbs_g = record.macros.carbs_g
        self.fat_g = record.macros.fat_g
        self.sourceRaw = record.source.rawValue
        self.provider = record.provider
        self.aiConfidence = record.aiConfidence
    }

    var record: FoodEntryRecord {
        FoodEntryRecord(
            id: id,
            timestamp: timestamp,
            name: name,
            macros: MacroNutrients(protein_g: protein_g, carbs_g: carbs_g, fat_g: fat_g),
            source: FoodSource(rawValue: sourceRaw) ?? .manual,
            provider: provider,
            aiConfidence: aiConfidence
        )
    }
}

@Model
final class MacroGoalEntity {
    var day: Date          // startOfDay
    var proteinTarget: Double
    var carbsTarget: Double
    var fatTarget: Double

    init(day: Date, goal: MacroGoal) {
        self.day = day
        self.proteinTarget = goal.proteinTarget
        self.carbsTarget = goal.carbsTarget
        self.fatTarget = goal.fatTarget
    }

    var goal: MacroGoal {
        MacroGoal(proteinTarget: proteinTarget, carbsTarget: carbsTarget, fatTarget: fatTarget)
    }
}

// MARK: - 共享容器（App Group）

public enum SharedStore {
    /// App Group 标识。真机分发前在两端 target 的 entitlements 中开启；
    /// 上架/签名时需将前缀换成你的 Team ID（如 group.<TEAMID>.ctapp.shared）。
    public static let appGroupID = "group.com.ctapp.shared"

    public enum StoreError: Error {
        case appGroupUnavailable   // 无 entitlements（如 CI 模拟器）时容器目录不存在
    }

    public static func makeContainer() throws -> ModelContainer {
        let url: URL
        if let dir = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            // 正常路径：App Group 共享容器，App 与 Widget 读写同一份数据。
            url = dir.appendingPathComponent("CT.sqlite")
        } else {
            // 降级路径：无 App Groups（侧载未配 Team ID / CI 模拟器）时用本进程沙盒。
            // 数据持久但仅本进程可见——App 可用，Widget 显示占位。
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            url = support.appendingPathComponent("CT.sqlite")
        }
        let config = ModelConfiguration(url: url)
        return try ModelContainer(
            for: FoodEntryEntity.self, MacroGoalEntity.self,
            configurations: config
        )
    }
}

// MARK: - 当日快照（Widget 与 App 共用的读取入口）

public struct DaySnapshot: Sendable {
    public var totals: MacroNutrients
    public var goal: MacroGoal?
    public static let empty = DaySnapshot(totals: .zero, goal: nil)
}

public enum TodayLoader {
    /// 从 App Group 容器读取当日聚合。
    /// 返回 nil 表示容器不可用（未配 entitlements）；数据为空时返回 .empty 快照。
    public static func load(calendar: Calendar = .current) -> DaySnapshot? {
        guard let container = try? SharedStore.makeContainer() else { return nil }
        let context = ModelContext(container)
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return .empty }

        do {
            var entryDescriptor = FetchDescriptor<FoodEntryEntity>(
                predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end }
            )
            entryDescriptor.sortBy = [SortDescriptor(\.timestamp)]
            let totals = try context.fetch(entryDescriptor)
                .reduce(MacroNutrients.zero) { $0 + $1.record.macros }

            let goalDescriptor = FetchDescriptor<MacroGoalEntity>(
                predicate: #Predicate { $0.day == start }
            )
            let goal = try context.fetch(goalDescriptor).first?.goal
            return DaySnapshot(totals: totals, goal: goal)
        } catch {
            return .empty
        }
    }
}

// MARK: - MacroStore 的 SwiftData 实现（App 侧写入）

/// App 主进程使用的持久化 Store。@MainActor 隔离，跨 actor 访问全部经由 async 协议方法串行化。
@MainActor
public final class SwiftDataStore {
    public static let shared = SwiftDataStore()

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    private init() {
        // 正常路径 App Group；无 entitlements（侧载未配 Team ID）时自动降级到本进程沙盒。
        container = try! SharedStore.makeContainer()
    }
}

extension SwiftDataStore: @unchecked Sendable {}

extension SwiftDataStore: MacroStore {
    public func addEntry(_ entry: FoodEntryRecord) async throws {
        context.insert(FoodEntryEntity(record: entry))
        try context.save()
    }

    public func deleteEntry(id: UUID) async throws {
        let descriptor = FetchDescriptor<FoodEntryEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try context.fetch(descriptor).first else { return }
        context.delete(entity)
        try context.save()
    }

    public func entries(from start: Date, to end: Date) async throws -> [FoodEntryRecord] {
        var descriptor = FetchDescriptor<FoodEntryEntity>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end }
        )
        descriptor.sortBy = [SortDescriptor(\.timestamp)]
        return try context.fetch(descriptor).map(\.record)
    }

    public func setGoal(_ goal: MacroGoal, for day: Date) async throws {
        let key = Calendar.current.startOfDay(for: day)
        let descriptor = FetchDescriptor<MacroGoalEntity>(
            predicate: #Predicate { $0.day == key }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.proteinTarget = goal.proteinTarget
            existing.carbsTarget = goal.carbsTarget
            existing.fatTarget = goal.fatTarget
        } else {
            context.insert(MacroGoalEntity(day: key, goal: goal))
        }
        try context.save()
    }

    public func goal(for day: Date) async throws -> MacroGoal? {
        let key = Calendar.current.startOfDay(for: day)
        let descriptor = FetchDescriptor<MacroGoalEntity>(
            predicate: #Predicate { $0.day == key }
        )
        return try context.fetch(descriptor).first?.goal
    }
}
#endif
