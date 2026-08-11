import Foundation

/// PRD §5.2's exact suggested session options, so a future timer UI doesn't scatter these
/// numbers across screens.
enum FocusTimerSessionLength: Hashable {
    case fifteenMinutes
    case thirtyMinutes
    case fortyFiveMinutes
    case oneHour
    case ninetyMinutes
    case custom(minutes: Int)

    var minutes: Int {
        switch self {
        case .fifteenMinutes: return 15
        case .thirtyMinutes: return 30
        case .fortyFiveMinutes: return 45
        case .oneHour: return 60
        case .ninetyMinutes: return 90
        case .custom(let minutes): return minutes
        }
    }

    static let suggested: [FocusTimerSessionLength] = [
        .fifteenMinutes, .thirtyMinutes, .fortyFiveMinutes, .oneHour, .ninetyMinutes,
    ]
}
