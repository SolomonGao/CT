// iOS-only：App Intents —— 唯一动作层（项目文档 §5.1 决策 1）。
// 同一个 Intent 同时供 Widget 按钮、控制中心、Siri、Shortcuts 复用。
// 本文件仅在 Apple 平台编译，Windows/CLI 构建时为空。

#if canImport(UIKit)
import AppIntents
import WidgetKit
import MacroCore

/// 管道B（参数化语音）："记 30 克蛋白质" —— 不经过 LLM，零成本零延迟。
/// 全中国可用（老 Siri + Shortcuts 即可）。
struct LogMacroIntent: AppIntent {
    static var title: LocalizedStringResource = "记录营养素"
    static var description = IntentDescription("直接记录一项营养素的克数，无需打开 App。")

    @Parameter(title: "蛋白质（克）")
    var protein: Double?

    @Parameter(title: "碳水（克）")
    var carbs: Double?

    @Parameter(title: "脂肪（克）")
    var fat: Double?

    init() {}

    init(protein: Double? = nil, carbs: Double? = nil, fat: Double? = nil) {
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }

    func perform() async throws -> some IntentResult {
        // TODO(P3): 接入 SwiftDataStore 写入 FoodEntryRecord(source: .voiceSiri)，
        //           然后刷新 Widget。
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// 打开 App 录入页（Widget"＋"按钮使用）。
struct OpenLogEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "记一笔"

    func perform() async throws -> some IntentResult {
        // TODO(P1): 深链到 App 的快速录入页（如 ctapp://log）。
        return .result()
    }
}

/// App Shortcuts 提供器：让"用 CT 记 30 克蛋白质"无需用户在 Shortcuts 里手动配置。
struct CTAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogMacroIntent(),
            phrases: [
                "用 \(.applicationName) 记蛋白质",
                "用 \(.applicationName) 记一笔",
            ]
        )
    }
}
#endif
