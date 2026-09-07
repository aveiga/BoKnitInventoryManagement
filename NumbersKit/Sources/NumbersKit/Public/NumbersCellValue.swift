import Foundation

public enum NumbersCellValue: Sendable, Equatable {
    case empty
    case text(String)
    case number(Double)
    case date(Date)
    case bool(Bool)
    case error

    public var stringValue: String? {
        switch self {
        case .text(let value): return value
        default: return nil
        }
    }

    public var doubleValue: Double? {
        switch self {
        case .number(let value): return value
        case .bool(let value): return value ? 1 : 0
        default: return nil
        }
    }

    public var intValue: Int? {
        doubleValue.map { Int($0.rounded()) }
    }
}
