import Foundation
import SwiftData

/// Reusable domain actions for the single app-wide Settings row, kept out of views per
/// CLAUDE.md §4.
enum SettingsService {
    typealias AppSettings = KyleOSSchemaV34.AppSettings

    /// Returns the one Settings row, creating it with PRD-default values on first launch.
    /// Safe to call repeatedly — never creates a second row.
    @discardableResult
    static func currentSettings(in context: ModelContext) throws -> AppSettings {
        var descriptor = FetchDescriptor<AppSettings>()
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }

    static func updateDayJobSchedule(
        _ settings: AppSettings,
        weekdays: [Int],
        startHour: Int,
        endHour: Int
    ) {
        settings.dayJobWeekdays = weekdays
        settings.dayJobStartHour = startHour
        settings.dayJobEndHour = endHour
        settings.updatedAt = .now
    }

    static func updateCreativeCapacity(
        _ settings: AppSettings,
        weekdayHours: Double,
        weekendHours: Double,
        standUpNightBonusHours: Double
    ) {
        settings.weekdayCreativeCapacityHours = weekdayHours
        settings.weekendCreativeCapacityHours = weekendHours
        settings.standUpNightBonusHours = standUpNightBonusHours
        settings.updatedAt = .now
    }

    static func updatePostsPerWeekTarget(_ settings: AppSettings, to target: Int) {
        settings.postsPerWeekTarget = max(target, 0)
        settings.updatedAt = .now
    }
}
