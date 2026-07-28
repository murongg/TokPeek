import Foundation
import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@Test("Localization resolves strings and formatted values from a selected bundle")
func localizationResolvesSelectedBundle() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("TokPeekLocalizationTests-\(UUID().uuidString)")
    let localizedResources = root.appendingPathComponent("zh-Hans.lproj")

    try FileManager.default.createDirectory(
        at: localizedResources,
        withIntermediateDirectories: true
    )
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let strings = """
        "Example greeting" = "示例问候";
        "Item count %lld" = "%lld 项";
        """
    try Data(strings.utf8).write(
        to: localizedResources.appendingPathComponent("Localizable.strings")
    )

    let bundle = try #require(Bundle(url: localizedResources))

    #expect(
        Localization.string(
            "Example greeting",
            bundle: bundle
        ) == "示例问候"
    )
    #expect(
        Localization.format(
            "Item count %lld",
            [Int64(3)],
            bundle: bundle,
            locale: Locale(identifier: "zh-Hans")
        ) == "3 项"
    )
}
