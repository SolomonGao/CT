// iOS-only：WidgetKit 骨架（项目文档 §7.2 规格）。
// 本文件仅在 Apple 平台编译，Windows/CLI 构建时为空。
// 注意：@main WidgetBundle 在 CTWidget Extension Target 中（Sources/CTWidget），
// 此处只提供 Provider、Entry 与视图，供 Extension 复用。

#if canImport(UIKit)
import SwiftUI
import WidgetKit
import MacroCore

public struct MacroEntry: TimelineEntry {
    public let date: Date
    public let totals: MacroNutrients
    public let goal: MacroGoal?
    public var progress: MacroDayProgress {
        IntakeAggregator.progress(totals: totals, goal: goal)
    }

    public init(date: Date, totals: MacroNutrients, goal: MacroGoal?) {
        self.date = date
        self.totals = totals
        self.goal = goal
    }
}

public struct MacroTimelineProvider: TimelineProvider {
    public init() {}

    // TODO(P1): 从 App Group 容器（SwiftDataStore）读取当日聚合结果。
    //           数据未就位前返回占位快照，保证 Widget 永不黑屏。
    private func snapshotEntry() -> MacroEntry {
        MacroEntry(
            date: Date(),
            totals: .zero,
            goal: MacroGoal(proteinTarget: 120, carbsTarget: 250, fatTarget: 60)
        )
    }

    public func placeholder(in context: Context) -> MacroEntry { snapshotEntry() }

    public func getSnapshot(in context: Context, completion: @escaping (MacroEntry) -> Void) {
        completion(snapshotEntry())
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<MacroEntry>) -> Void) {
        // 写操作后由 App/Intent 主动 reloadTimelines；此处仅做餐点时段的被动兜底。
        let nextMeal = Calendar.current.nextDate(
            after: Date(), matching: DateComponents(hour: 8), matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [snapshotEntry()], policy: .after(nextMeal)))
    }
}

/// systemSmall：三条进度条 + "＋"按钮（打开 App 录入页）。
public struct MacroWidgetSmall: View {
    let entry: MacroEntry

    public init(entry: MacroEntry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(spacing: 10) {
            MacroProgressTriple(dayProgress: entry.progress)
            Spacer(minLength: 0)
            Button(intent: OpenLogEntryIntent()) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// systemMedium：三条进度条 + 大数字 + 已录条数（已录条数 TODO 接入）。
public struct MacroWidgetMedium: View {
    let entry: MacroEntry

    public init(entry: MacroEntry) {
        self.entry = entry
    }

    public var body: some View {
        HStack(spacing: 20) {
            MacroProgressTriple(dayProgress: entry.progress)
                .frame(maxWidth: .infinity)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(entry.totals.energy_kcal.rounded()))")
                    .font(.title.bold())
                Text("kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

public struct MacroWidget: Widget {
    public let kind: String = "MacroWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MacroTimelineProvider()) { entry in
            MacroWidgetSmall(entry: entry)
        }
        .configurationDisplayName("今日营养")
        .description("蛋白质 / 碳水 / 脂肪进度")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
#endif
