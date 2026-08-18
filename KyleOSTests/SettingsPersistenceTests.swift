import XCTest
import SwiftData
@testable import KyleOS

/// Covers the Foundation acceptance criteria "Day-job and Creative Capacity settings exist"
/// and confirms Settings really is a singleton row, not something that quietly duplicates.
final class SettingsPersistenceTests: XCTestCase {

    func testCurrentSettingsCreatesDefaultsOnFirstCall() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let settings = try SettingsService.currentSettings(in: context)
        try context.save()

        XCTAssertEqual(settings.dayJobWeekdays, [2, 3, 4, 5, 6], "Default day job should be Mon-Fri")
        XCTAssertEqual(settings.dayJobStartHour, 8)
        XCTAssertEqual(settings.dayJobEndHour, 17)
        XCTAssertEqual(settings.weekdayCreativeCapacityHours, 2.5)
        XCTAssertEqual(settings.standUpNightBonusHours, 1.0)
        XCTAssertNil(settings.weekendCreativeCapacityHours, "Unset until the user explicitly configures a weekend value")
        XCTAssertEqual(settings.displayWeekendCreativeCapacityHours, 2.5, "Falls back to the weekday default")
    }

    func testCurrentSettingsNeverCreatesASecondRow() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let first = try SettingsService.currentSettings(in: context)
        try context.save()
        let second = try SettingsService.currentSettings(in: context)
        try context.save()

        XCTAssertEqual(first.id, second.id)
        let allSettings = try context.fetch(FetchDescriptor<SettingsService.AppSettings>())
        XCTAssertEqual(allSettings.count, 1)
    }

    func testUpdatingDayJobAndCapacityPersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let settings = try SettingsService.currentSettings(in: context)
        SettingsService.updateDayJobSchedule(settings, weekdays: [2, 3, 4, 5, 6, 7], startHour: 9, endHour: 18)
        SettingsService.updateCreativeCapacity(settings, weekdayHours: 3, weekendHours: 6, standUpNightBonusHours: 1.5)
        try context.save()

        let reloaded = try SettingsService.currentSettings(in: context)
        XCTAssertEqual(reloaded.dayJobWeekdays, [2, 3, 4, 5, 6, 7])
        XCTAssertEqual(reloaded.dayJobStartHour, 9)
        XCTAssertEqual(reloaded.dayJobEndHour, 18)
        XCTAssertEqual(reloaded.weekdayCreativeCapacityHours, 3)
        XCTAssertEqual(reloaded.weekendCreativeCapacityHours, 6)
        XCTAssertEqual(reloaded.standUpNightBonusHours, 1.5)
    }
}
