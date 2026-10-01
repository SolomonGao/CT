import Foundation

// MARK: - 三大营养素

/// 一份食物（或一天合计）的宏量营养素，单位：克。
public struct MacroNutrients: Equatable, Sendable {
    public var protein_g: Double
    public var carbs_g: Double
    public var fat_g: Double

    public init(protein_g: Double = 0, carbs_g: Double = 0, fat_g: Double = 0) {
        self.protein_g = protein_g
        self.carbs_g = carbs_g
        self.fat_g = fat_g
    }

    public static let zero = MacroNutrients()

    /// Atwater 系数估算热量：4/4/9 kcal per gram。
    public var energy_kcal: Double {
        protein_g * 4 + carbs_g * 4 + fat_g * 9
    }

    public static func + (lhs: MacroNutrients, rhs: MacroNutrients) -> MacroNutrients {
        MacroNutrients(
            protein_g: lhs.protein_g + rhs.protein_g,
            carbs_g: lhs.carbs_g + rhs.carbs_g,
            fat_g: lhs.fat_g + rhs.fat_g
        )
    }
}

// MARK: - 记录来源

/// 记录来源管道，对应项目文档 §2 的四条输入管道。
public enum FoodSource: String, Codable, Sendable, CaseIterable {
    case manual     // 管道A: 手动填写
    case voiceSiri  // 管道B: Siri 参数化语音（"记 30 克蛋白质"）
    case voiceAI    // 管道B: 语音 + AI 解析估算
    case textAI     // 管道C: 自然语言文本 + AI
    case photoAI    // 管道D: 拍照 + AI 视觉估算
}

// MARK: - 食物记录

/// 一条已确认的食物记录（管道的最终产物）。
public struct FoodEntryRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var timestamp: Date
    public var name: String
    public var macros: MacroNutrients
    public var source: FoodSource
    /// 使用的 AI 后端标识（如 "kimi-k2.6"），手动/参数化记录为 nil，便于历史回溯。
    public var provider: String?
    /// AI 估算置信度 0...1，手动记录为 nil。
    public var aiConfidence: Double?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        name: String,
        macros: MacroNutrients,
        source: FoodSource = .manual,
        provider: String? = nil,
        aiConfidence: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.name = name
        self.macros = macros
        self.source = source
        self.provider = provider
        self.aiConfidence = aiConfidence
    }
}

// MARK: - 每日目标

/// 某一天的三大营养素目标，单位：克。
public struct MacroGoal: Equatable, Sendable {
    public var proteinTarget: Double
    public var carbsTarget: Double
    public var fatTarget: Double

    public init(proteinTarget: Double, carbsTarget: Double, fatTarget: Double) {
        self.proteinTarget = proteinTarget
        self.carbsTarget = carbsTarget
        self.fatTarget = fatTarget
    }

    public var isEmpty: Bool { proteinTarget <= 0 && carbsTarget <= 0 && fatTarget <= 0 }
}

// MARK: - 确认页草稿（AI 管道出口，未落库）

/// AI 管道解析/估算后的待确认项；确认后才转为 FoodEntryRecord 写入 Store。
public struct EntryDraft: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    /// 用户可见的估算分量描述，如 "~180g"、"一碗"。
    public var portionDescription: String
    public var macros: MacroNutrients
    public var confidence: Double?

    public init(
        id: UUID = UUID(),
        name: String,
        portionDescription: String = "",
        macros: MacroNutrients,
        confidence: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.portionDescription = portionDescription
        self.macros = macros
        self.confidence = confidence
    }
}
