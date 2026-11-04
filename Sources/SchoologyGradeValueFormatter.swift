import Foundation
enum SchoologyGradeValueFormatter {
    static func display(_ rawValue: String) -> String {
        let pattern = #"^\s*([+-]?\d+(?:\.\d+)?)(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: rawValue, range: NSRange(rawValue.startIndex..., in: rawValue)),
              let numberRange = Range(match.range(at: 1), in: rawValue),
              let suffixRange = Range(match.range(at: 2), in: rawValue),
              let number = Decimal(string: String(rawValue[numberRange]), locale: Locale(identifier: "en_US_POSIX")) else { return rawValue }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        guard let formatted = formatter.string(from: number as NSDecimalNumber) else { return rawValue }
        return formatted + rawValue[suffixRange]
    }
}
