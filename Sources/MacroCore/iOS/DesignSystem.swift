// iOS-only：设计系统。三营养素固定色码，全 App / 全 Widget 一致（项目文档 §7.1）。
// 本文件仅在 Apple 平台编译，Windows/CLI 构建时为空。

#if canImport(SwiftUI)
import SwiftUI
import MacroCore

public enum MacroColor {
    public static let protein = Color(hex: 0xFF5A5F) // 珊瑚红
    public static let carbs   = Color(hex: 0xFFB340) // 琥珀
    public static let fat     = Color(hex: 0x32ADE6) // 青蓝
}

public extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// 单条营养素进度条。App 今日页与 Widget 共用，保证观感一致。
public struct MacroProgressBar: View {
    let label: String
    let progress: MacroProgress
    let tint: Color

    public init(label: String, progress: MacroProgress, tint: Color) {
        self.label = label
        self.progress = progress
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 28, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(tint.opacity(0.18))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(progress.over ? Color.red : tint)
                        .frame(width: geo.size.width * progress.ratio)
                }
            }
            .frame(height: 6)
            Text("\(Int(progress.consumed.rounded()))/\(Int(progress.target.rounded()))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

/// 三条营养素进度条组合，今日页 / Widget systemSmall 共用。
public struct MacroProgressTriple: View {
    let dayProgress: MacroDayProgress

    public init(dayProgress: MacroDayProgress) {
        self.dayProgress = dayProgress
    }

    public var body: some View {
        VStack(spacing: 10) {
            MacroProgressBar(label: "蛋白", progress: dayProgress.protein, tint: MacroColor.protein)
            MacroProgressBar(label: "碳水", progress: dayProgress.carbs, tint: MacroColor.carbs)
            MacroProgressBar(label: "脂肪", progress: dayProgress.fat, tint: MacroColor.fat)
        }
    }
}
#endif
