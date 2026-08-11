import XCTest
import SwiftData
@testable import KyleOS

/// Covers the Foundation acceptance criterion "Work Type Defaults exist and are not scattered
/// hard-coded values."
final class WorkTypeDefaultTests: XCTestCase {

    func testSeedingCreatesThePRDsKnownDefaults() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        try WorkTypeDefaultService.seedKnownDefaultsIfNeeded(in: context)
        try context.save()

        let all = try WorkTypeDefaultService.all(in: context)
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all.first { $0.name == "Outline" }?.defaultEstimateHours, 1.5)
        XCTAssertEqual(all.first { $0.name == "Short Story" }?.defaultEstimateHours, 3.0)
    }

    func testSeedingTwiceDoesNotDuplicate() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        try WorkTypeDefaultService.seedKnownDefaultsIfNeeded(in: context)
        try WorkTypeDefaultService.seedKnownDefaultsIfNeeded(in: context)
        try context.save()

        let all = try WorkTypeDefaultService.all(in: context)
        XCTAssertEqual(all.count, 2, "Seeding twice must not create duplicate rows")
    }

    func testCreatingACustomWorkTypeDefaultPersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let clipEdit = WorkTypeDefaultService.createWorkTypeDefault(
            name: "Clip Edit",
            defaultEstimateHours: 2,
            preferredSessionMinutes: 30,
            minimumSessionMinutes: 15,
            isSplittable: true,
            in: context
        )
        try context.save()

        let all = try WorkTypeDefaultService.all(in: context)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, clipEdit.id)
        XCTAssertEqual(all.first?.name, "Clip Edit")
        XCTAssertEqual(all.first?.preferredSessionMinutes, 30)
    }

    func testUpdatingAWorkTypeDefaultPersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let workType = WorkTypeDefaultService.createWorkTypeDefault(
            name: "Sketch Edit",
            defaultEstimateHours: 2,
            in: context
        )
        try context.save()

        WorkTypeDefaultService.update(
            workType,
            defaultEstimateHours: 2.5,
            preferredSessionMinutes: 60,
            minimumSessionMinutes: 20,
            isSplittable: false
        )
        try context.save()

        let reloaded = try WorkTypeDefaultService.all(in: context).first { $0.id == workType.id }
        XCTAssertEqual(reloaded?.defaultEstimateHours, 2.5)
        XCTAssertEqual(reloaded?.preferredSessionMinutes, 60)
        XCTAssertEqual(reloaded?.isSplittable, false)
    }
}
