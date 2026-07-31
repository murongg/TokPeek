public enum MenuBarIcon {
    public static let systemName = "chart.bar"
    public static let usesBrandMarkInSummary = true
    public static let usesBrandMarkInIconOnly = true
}

public enum MenuBarBudgetProgressLayout {
    public static let trackWidth = 22.0
    public static let trackHeight = 8.0
    public static let artworkWidth = 24.0
    public static let artworkHeight = 18.0

    public static func fillWidth(
        for progress: Double?
    ) -> Double {
        guard let progress else {
            return 0
        }

        return trackWidth * min(max(progress, 0), 1)
    }
}
