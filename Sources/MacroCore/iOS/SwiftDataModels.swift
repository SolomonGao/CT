// iOS-only：SwiftData 持久层。本文件仅在 Apple 平台编译（#if canImport 保护），
// Windows/CLI 构建时为空。P1 阶段先给出模型与映射，SwiftDataStore 实现随后接入 App Group 容器。

#if canImport(SwiftData)
import Foundation
import SwiftData
import MacroCore

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

// TODO(P1): public struct SwiftDataStore: MacroStore —— ModelContainer 指向
//   FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.<team>.CT")
//   下的 store.sqlite，保证 App 与 Widget Extension 读写同一份数据。
#endif
