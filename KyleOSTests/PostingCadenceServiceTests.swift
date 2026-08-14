import XCTest
@testable import KyleOS

final class PostingCadenceServiceTests: XCTestCase {

    /// The upcoming (or current) Monday in local time — avoids any week-boundary edge cases from
    /// running near the end of a week.
    private func mondayAt(_ hour: Int = 9) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilMonday = (2 - weekday + 7) % 7
        let monday = calendar.date(byAdding: .day, value: daysUntilMonday, to: today)!
        return calendar.date(byAdding: .hour, value: hour, to: monday)!
    }

    func testSuggestsExactlyTargetCountWhenNoExistingConfirmedDates() {
        let monday = mondayAt()
        let suggestions = PostingCadenceService.suggestedDates(target: 3, confirmedDates: [], startingFrom: monday, weeksAhead: 1)

        XCTAssertEqual(suggestions.count, 3)
    }

    func testSuggestsFewerWhenSomeSlotsAlreadyConfirmedThatWeek() {
        let monday = mondayAt()
        let wednesday = Calendar.current.date(byAdding: .day, value: 2, to: monday)!
        let suggestions = PostingCadenceService.suggestedDates(target: 3, confirmedDates: [wednesday], startingFrom: monday, weeksAhead: 1)

        XCTAssertEqual(suggestions.count, 2, "One of the three weekly slots is already filled")
    }

    func testSuggestsNothingWhenTargetAlreadyMetThatWeek() {
        let monday = mondayAt()
        let calendar = Calendar.current
        let confirmed = (0..<3).map { calendar.date(byAdding: .day, value: $0, to: monday)! }
        let suggestions = PostingCadenceService.suggestedDates(target: 3, confirmedDates: confirmed, startingFrom: monday, weeksAhead: 1)

        XCTAssertTrue(suggestions.isEmpty)
    }

    func testNeverSuggestsADayThatAlreadyHasAConfirmedPost() {
        let monday = mondayAt()
        let calendar = Calendar.current
        let wednesday = calendar.date(byAdding: .day, value: 2, to: monday)!
        let suggestions = PostingCadenceService.suggestedDates(target: 3, confirmedDates: [wednesday], startingFrom: monday, weeksAhead: 1)

        XCTAssertFalse(suggestions.contains { calendar.isDate($0, inSameDayAs: wednesday) }, "Avoiding clustering means never doubling up an already-used day")
    }

    func testNeverSuggestsADateBeforeStartingFrom() {
        let monday = mondayAt()
        let suggestions = PostingCadenceService.suggestedDates(target: 7, confirmedDates: [], startingFrom: monday, weeksAhead: 1)

        XCTAssertTrue(suggestions.allSatisfy { $0 >= Calendar.current.startOfDay(for: monday) })
    }

    func testSuggestsAcrossMultipleWeeksWhenAsked() {
        let monday = mondayAt()
        let suggestions = PostingCadenceService.suggestedDates(target: 2, confirmedDates: [], startingFrom: monday, weeksAhead: 3)

        XCTAssertEqual(suggestions.count, 6, "2 per week across 3 weeks")
    }

    func testZeroTargetSuggestsNothing() {
        let suggestions = PostingCadenceService.suggestedDates(target: 0, confirmedDates: [], startingFrom: mondayAt())
        XCTAssertTrue(suggestions.isEmpty)
    }

    func testSpreadsSuggestionsAcrossTheWeekRatherThanClusteringAtTheStart() {
        let monday = mondayAt()
        let calendar = Calendar.current
        let suggestions = PostingCadenceService.suggestedDates(target: 2, confirmedDates: [], startingFrom: monday, weeksAhead: 1)

        guard suggestions.count == 2 else {
            return XCTFail("Expected 2 suggestions")
        }
        let daysBetween = calendar.dateComponents([.day], from: suggestions[0], to: suggestions[1]).day ?? 0
        XCTAssertGreaterThan(daysBetween, 1, "Two picks in a 7-day week should not be adjacent days")
    }
}
