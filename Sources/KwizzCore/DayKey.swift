import Foundation

/// Converts a compact calendar key (e.g. 20260605) into a serial day number
/// (days since 1970-01-01), so day-to-day gaps are correct across month and year
/// boundaries. The streak logic relies on this: `YYYYMMDD` subtraction is wrong
/// (20260601 - 20260531 != 1), serial subtraction is right. Pure and deterministic.
public enum DayKey {
    /// Days-from-civil (Howard Hinnant's algorithm). Valid for the proleptic
    /// Gregorian calendar; deterministic, no RNG, no Calendar dependency.
    public static func serial(_ yyyymmdd: Int) -> Int {
        let y = yyyymmdd / 10000
        let m = (yyyymmdd / 100) % 100
        let d = yyyymmdd % 100

        let yy = (m <= 2) ? y - 1 : y
        let era = (yy >= 0 ? yy : yy - 399) / 400
        let yoe = yy - era * 400                                  // [0, 399]
        let mp = (m > 2) ? m - 3 : m + 9                          // [0, 11]
        let doy = (153 * mp + 2) / 5 + d - 1                      // [0, 365]
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy           // [0, 146096]
        return era * 146097 + doe - 719468
    }
}
