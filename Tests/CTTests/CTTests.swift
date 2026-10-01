import Foundation
import Testing
@testable import MacroCore

private func makeDate(_ calendar: Calendar, _ dayOffset: Int, hour: Int = 12) -> Date {
    // 2026-10-05 是周一；dayOffset 为相对周一的偏移天数
    let monday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5))!
    let day = calendar.date(byAdding: .day, value: dayOffset, to: monday)!
    return calendar.date(byAdding: .hour, value: hour, to: day)!
}

@Suite("IntakeAggregator")
struct AggregatorTests {
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    @Test("当日合计只统计当天的记录")
    func dailyTotalsFilterByDay() {
        let day0 = makeDate(calendar, 0)
        let day1 = makeDate(calendar, 1)
        let entries = [
            FoodEntryRecord(timestamp: makeDate(calendar, 0, hour: 8), name: "早餐",
                            macros: MacroNutrients(protein_g: 10, carbs_g: 20, fat_g: 5)),
            FoodEntryRecord(timestamp: makeDate(calendar, 0, hour: 19), name: "晚餐",
                            macros: MacroNutrients(protein_g: 20, carbs_g: 40, fat_g: 10)),
            FoodEntryRecord(timestamp: day1, name: "明天的饭",
                            macros: MacroNutrients(protein_g: 99, carbs_g: 99, fat_g: 99)),
        ]
        let totals = IntakeAggregator.totals(entries, on: day0, calendar: calendar)
        #expect(totals == MacroNutrients(protein_g: 30, carbs_g: 60, fat_g: 15))
    }

    @Test("进度按目标截断到 0...1 并标记超出")
    func progressClampedAndOverFlag() {
        let goal = MacroGoal(proteinTarget: 100, carbsTarget: 200, fatTarget: 50)
        let p = IntakeAggregator.progress(
            totals: MacroNutrients(protein_g: 150, carbs_g: 100, fat_g: 50),
            goal: goal
        )
        #expect(p.protein.ratio == 1)
        #expect(p.protein.over == true)
        #expect(p.carbs.ratio == 0.5)
        #expect(p.carbs.over == false)
        #expect(p.fat.ratio == 1)
        #expect(p.fat.over == false) // 恰好等于目标不算超出
    }

    @Test("无目标时进度为 0 不崩溃")
    func progressWithoutGoal() {
        let p = IntakeAggregator.progress(totals: MacroNutrients(protein_g: 50, carbs_g: 0, fat_g: 0), goal: nil)
        #expect(p.protein.ratio == 0)
        #expect(p.protein.over == false)
    }

    @Test("周视图从周一开始共 7 天")
    func weekDatesStartOnMonday() {
        // 2026-10-07 是周三
        let wed = makeDate(calendar, 2)
        let week = IntakeAggregator.weekDates(containing: wed, calendar: calendar)
        #expect(week.count == 7)
        #expect(calendar.component(.weekday, from: week[0]) == 2) // Monday
        #expect(week[6] == makeDate(calendar, 6, hour: 0))
    }

    @Test("周汇总逐天关联各自目标")
    func weeklySummaryUsesPerDayGoals() async throws {
        let store = InMemoryStore(calendar: calendar)
        let mon = makeDate(calendar, 0)
        try await store.setGoal(MacroGoal(proteinTarget: 100, carbsTarget: 200, fatTarget: 50), for: mon)
        try await store.setGoal(MacroGoal(proteinTarget: 150, carbsTarget: 300, fatTarget: 70), for: makeDate(calendar, 2))
        try await store.addEntry(FoodEntryRecord(
            timestamp: makeDate(calendar, 2, hour: 8), name: "早餐",
            macros: MacroNutrients(protein_g: 75, carbs_g: 150, fat_g: 35)
        ))
        let entries = try await store.entries(from: mon, to: makeDate(calendar, 7))
        let summary = await IntakeAggregator.weeklySummary(
            entries: entries,
            goalFor: { try? await store.goal(for: $0) },
            around: makeDate(calendar, 2),
            calendar: calendar
        )
        #expect(summary.count == 7)
        #expect(summary[0].goal?.proteinTarget == 100)
        #expect(summary[2].goal?.proteinTarget == 150)
        #expect(summary[2].progress.protein.ratio == 0.5)
        #expect(summary[1].totals == .zero)
    }
}

@Suite("InMemoryStore")
struct StoreTests {
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    @Test("增删查与目标读写")
    func crud() async throws {
        let store = InMemoryStore(calendar: calendar)
        let e1 = FoodEntryRecord(timestamp: makeDate(calendar, 0, hour: 8),
                                 name: "米饭", macros: MacroNutrients(carbs_g: 52))
        let e2 = FoodEntryRecord(timestamp: makeDate(calendar, 0, hour: 19),
                                 name: "牛肉", macros: MacroNutrients(protein_g: 31))
        try await store.addEntry(e1)
        try await store.addEntry(e2)
        let dayStart = makeDate(calendar, 0, hour: 0)
        let dayEnd = makeDate(calendar, 1, hour: 0)
        var all = try await store.entries(from: dayStart, to: dayEnd)
        #expect(all.count == 2)
        #expect(all.first?.name == "米饭") // 按时间排序

        try await store.deleteEntry(id: e1.id)
        all = try await store.entries(from: dayStart, to: dayEnd)
        #expect(all.count == 1)
        #expect(all.first?.id == e2.id)

        #expect(try await store.goal(for: dayStart) == nil)
        let goal = MacroGoal(proteinTarget: 120, carbsTarget: 250, fatTarget: 60)
        try await store.setGoal(goal, for: dayStart)
        #expect(try await store.goal(for: dayStart) == goal)
        // 同一天的不同时刻读取，应归一到同一天
        #expect(try await store.goal(for: makeDate(calendar, 0, hour: 23)) == goal)
    }
}
