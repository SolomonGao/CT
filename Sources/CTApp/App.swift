import SwiftUI
import MacroCore

// CT iOS App 入口。数据由 TodayView 自身从共享容器加载（见 AppViews.swift）。

@main
struct CTApp: App {
    var body: some Scene {
        WindowGroup {
            TodayView()
        }
    }
}
