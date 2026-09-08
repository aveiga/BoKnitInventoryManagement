import Foundation

/// Money handling for the app. Prices arrive from the Numbers sheet as `Double`s,
/// so they're rounded to cents once on the way in and carried as `Decimal` from
/// then on — that keeps basket and revenue totals from inheriting the sheet's
/// float noise (a PVP of `5.800000000000001` becomes exactly `5.80`).
enum BKCurrency {
    static let code = "EUR"

    /// Rounds a raw spreadsheet number to a cent-exact `Decimal`.
    static func decimal(fromSheetValue value: Double) -> Decimal {
        Decimal(Int((value * 100).rounded())) / 100
    }

    /// Display form, e.g. "€3.50". Placement follows the device locale; the
    /// currency is always euro.
    static func string(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: code).precision(.fractionLength(2)))
    }

    /// Locale-independent form for CSV export, e.g. "3.50".
    static func csvString(_ amount: Decimal) -> String {
        amount.formatted(
            .number
                .precision(.fractionLength(2))
                .grouping(.never)
                .locale(Locale(identifier: "en_US_POSIX"))
        )
    }
}
