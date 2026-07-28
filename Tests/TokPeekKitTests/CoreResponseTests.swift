import Foundation
import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@Test("A failed bridge response surfaces the Rust error message")
func failedBridgeResponseSurfacesError() throws {
    let data = Data(
        #"{"ok":false,"error":"Synthetic Tokscale failure"}"#.utf8
    )
    let response = try CoreJSON.decoder.decode(
        CoreResponse<UsageReport>.self,
        from: data
    )

    #expect(throws: CoreResponseError.self) {
        try response.value()
    }

    do {
        _ = try response.value()
    } catch {
        #expect(error.localizedDescription == "Synthetic Tokscale failure")
    }
}
