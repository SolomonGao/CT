import Foundation
import MacroCore

// CLI 演示：在 Windows 上验证 P1 核心逻辑（模型 → 存储 → 聚合 → 进度），
// 不依赖任何 iOS 框架。正式 App 中同等逻辑由 SwiftUI 视图与 Widget 消费。

@main
struct CT {
    static func main() async throws {
        let calendar = Calendar.current
        let today = Date()
        let store = InMemoryStore(calendar: calendar)

        // 1. 设定今日目标
        let goal = MacroGoal(proteinTarget: 120, carbsTarget: 250, fatTarget: 60)
        try await store.setGoal(goal, for: today)

        // 2. 记录两餐（手动管道）
        try await store.addEntry(FoodEntryRecord(
            name: "米饭",
            macros: MacroNutrients(protein_g: 5, carbs_g: 52, fat_g: 1),
            source: .manual
        ))
        try await store.addEntry(FoodEntryRecord(
            name: "酱牛肉",
            macros: MacroNutrients(protein_g: 31, carbs_g: 2, fat_g: 12),
            source: .manual
        ))
        // 一条 AI 管道的记录（带置信度），演示历史可回溯
        try await store.addEntry(FoodEntryRecord(
            name: "番茄炒蛋",
            macros: MacroNutrients(protein_g: 12, carbs_g: 9, fat_g: 18),
            source: .photoAI,
            provider: "kimi-k2.6",
            aiConfidence: 0.62
        ))

        // 3. 聚合当日进度
        let dayStart = calendar.startOfDay(for: today)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }
        let entries = try await store.entries(from: dayStart, to: dayEnd)
        let totals = IntakeAggregator.totals(entries, on: today, calendar: calendar)
        let progress = IntakeAggregator.progress(totals: totals, goal: try await store.goal(for: today))

        // 4. 打印
        print("== CT · 今日摄入 ==\n")
        print(bar("蛋白", progress.protein))
        print(bar("碳水", progress.carbs))
        print(bar("脂肪", progress.fat))
        print("\n合计 \(Int(totals.energy_kcal.rounded())) kcal · 共 \(entries.count) 条记录")
        for e in entries {
            let tag = e.source == .manual ? "手动" : "\(e.source.rawValue) \(e.provider ?? "")"
            print("  · \(e.name): P\(Int(e.macros.protein_g)) C\(Int(e.macros.carbs_g)) F\(Int(e.macros.fat_g))  [\(tag)]")
        }
    }

    static func bar(_ label: String, _ p: MacroProgress) -> String {
        let width = 24
        let filled = p.target > 0 ? Int((p.ratio * Double(width)).rounded()) : 0
        let overMark = p.over ? " ↑超出" : ""
        return String(format: "%@ %@", label,
                      String(repeating: "█", count: filled)
                      + String(repeating: "░", count: width - filled))
            + String(format: "  %3.0f/%3.0f g%@", p.consumed, p.target, overMark)
    }
}
