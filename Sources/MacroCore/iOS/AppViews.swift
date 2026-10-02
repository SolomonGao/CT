// iOS-only：SwiftUI App 骨架（今日页 / 录入页 / 目标设置）。
// 本文件仅在 Apple 平台编译，Windows/CLI 构建时为空。
// 注意：库中不提供 @main，Xcode App Target 中写 @main struct CTApp: App { ... }。

#if canImport(UIKit)
import SwiftUI
import MacroCore

public struct TodayView: View {
    let totals: MacroNutrients
    let goal: MacroGoal?
    public init(totals: MacroNutrients, goal: MacroGoal?) {
        self.totals = totals
        self.goal = goal
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                MacroProgressTriple(
                    dayProgress: IntakeAggregator.progress(totals: totals, goal: goal)
                )
                .padding(.horizontal)
                // TODO(P1): 今日已录列表（左滑删除）+ NavigationLink 到周视图/详情页。
                Spacer()
            }
            .navigationTitle("今日")
        }
    }
}

/// 手动录入页：三个数字框 + 名称选填（管道 A，永远无 AI、无确认）。
public struct LogEntryView: View {
    @State private var name = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    public init() {}

    public var body: some View {
        Form {
            TextField("名称（选填）", text: $name)
            TextField("蛋白质（克）", text: $protein)
                .keyboardType(.decimalPad)
            TextField("碳水（克）", text: $carbs)
                .keyboardType(.decimalPad)
            TextField("脂肪（克）", text: $fat)
                .keyboardType(.decimalPad)
        }
        // TODO(P1): 保存 → store.addEntry(source: .manual) → 返回并刷新 Widget。
    }
}

/// 目标设置：三个大数字 + "应用到整周"。
public struct GoalSetupView: View {
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var applyToWeek = true
    public init() {}

    public var body: some View {
        Form {
            TextField("蛋白质目标（克/天）", text: $protein)
                .keyboardType(.decimalPad)
            TextField("碳水目标（克/天）", text: $carbs)
                .keyboardType(.decimalPad)
            TextField("脂肪目标（克/天）", text: $fat)
                .keyboardType(.decimalPad)
            Toggle("应用到整周", isOn: $applyToWeek)
        }
        // TODO(P1): 保存 → 写 7 天 MacroGoal → WidgetCenter.reloadAllTimelines()。
    }
}
#endif
