import Foundation

public enum Localization {
    public static func string(
        _ key: String,
        bundle: Bundle = .main
    ) -> String {
        bundle.localizedString(
            forKey: key,
            value: nil,
            table: nil
        )
    }

    public static func format(
        _ key: String,
        _ arguments: [CVarArg],
        bundle: Bundle = .main,
        locale: Locale = .current
    ) -> String {
        String(
            format: string(key, bundle: bundle),
            locale: locale,
            arguments: arguments
        )
    }
}
