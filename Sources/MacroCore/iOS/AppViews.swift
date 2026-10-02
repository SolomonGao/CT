// iOS-only：SwiftUI App 骨架（今日页 / 录入页 / 目标设置）。
// 本文件仅在 iOS 编译，Windows/CLI 构建时为空。
// 注意：库中不提供 @main，Xcode App Target 中写 @main struct CTApp: App { ... }。

#if canImport(UIKit)
import SwiftUI
import WidgetKit
import MacroCore

/// 今日页：真实数据驱动——顶部三条进度条 + 今日已录列表（左滑删除）。
public struct TodayView: View {
    @State private var totals: MacroNutrients = .zero
    @State private var goal: MacroGoal?
    @State private var entries: [FoodEntryRecord] = []
    @State private var showingLogEntry = false
    @State private var showingGoalSetup = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                MacroProgressTriple(
                    dayProgress: IntakeAggregator.progress(totals: totals, goal: goal)
                )
                .padding(.horizontal)

                List {
                    ForEach(entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name)
                                Text(entry.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("P\(entry.macros.protein_g.formatted(.number.precision(.fractionLength(0)))) "
                                 + "C\(entry.macros.carbs_g.formatted(.number.precision(.fractionLength(0)))) "
                                 + "F\(entry.macros.fat_g.formatted(.number.precision(.fractionLength(0))))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: deleteEntries)
                }
                .listStyle(.plain)
            }
            .navigationTitle("今日")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingGoalSetup = true } label: {
                        Image(systemName: "target")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingLogEntry = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingLogEntry, onDismiss: { Task { await refresh() } }) {
                LogEntryView()
            }
            .sheet(isPresented: $showingGoalSetup, onDismiss: { Task { await refresh() } }) {
                NavigationStack { GoalSetupView() }
            }
            .task { await refresh() }
        }
    }

    private func refresh() async {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        entries = (try? await SwiftDataStore.shared.entries(from: start, to: end)) ?? []
        totals = entries.reduce(.zero) { $0 + $1.macros }
        goal = try? await SwiftDataStore.shared.goal(for: Date())
    }

    private func deleteEntries(at offsets: IndexSet) {
        Task {
            for index in offsets {
                try? await SwiftDataStore.shared.deleteEntry(id: entries[index].id)
            }
            await refresh()
        }
    }
}

/// 手动录入页：三个数字框 + 名称选填（管道 A，永远无 AI、无确认）。
public struct LogEntryView: View {
    @Environment(\.dismiss) private var dismiss
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
        .navigationTitle("记一笔")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { Task { await save() } }
            }
        }
    }

    private func save() async {
        let parse: (String) -> Double = { Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        let entry = FoodEntryRecord(
            name: name.isEmpty ? "手动记录" : name,
            macros: MacroNutrients(protein_g: parse(protein), carbs_g: parse(carbs), fat_g: parse(fat)),
            source: .manual
        )
        try? await SwiftDataStore.shared.addEntry(entry)
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }
}

/// 目标设置：三个大数字 + "应用到整周"。
public struct GoalSetupView: View {
    @Environment(\.dismiss) private var dismiss
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
        .navigationTitle("每日目标")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { Task { await save() } }
            }
        }
    }

    private func save() async {
        let parse: (String) -> Double = { Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        let goal = MacroGoal(
            proteinTarget: parse(protein),
            carbsTarget: parse(carbs),
            fatTarget: parse(fat)
        )
        let days = applyToWeek
            ? IntakeAggregator.weekDates(containing: Date())
            : [Date()]
        for day in days {
            try? await SwiftDataStore.shared.setGoal(goal, for: day)
        }
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }
}
#endif
