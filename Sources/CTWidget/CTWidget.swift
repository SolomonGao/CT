import SwiftUI
import WidgetKit
import MacroCore

// Widget Extension 入口。Provider 与视图来自 MacroCore（iOS 编译时生效），
// App 与 Widget 因此共用同一套聚合逻辑与组件，数字永远一致。

@main
struct CTWidgetBundle: WidgetBundle {
    var body: some Widget {
        MacroWidget()
    }
}
