import SwiftUI
import MacroCore

// CT iOS App 入口。P1 阶段视图以占位数据渲染；
// TODO(P1): 接入 SwiftDataStore 后，TodayView 改由 Store 当日聚合驱动。

@main
struct CTApp: App {
    var body: some Scene {
        WindowGroup {
            TodayView(totals: .zero, goal: nil)
        }
    }
}
