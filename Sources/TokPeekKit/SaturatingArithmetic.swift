extension Int64 {
    func saturatingAdd(_ other: Int64) -> Int64 {
        let (value, overflow) = addingReportingOverflow(other)
        guard overflow else {
            return value
        }
        return other >= 0 ? .max : .min
    }
}
