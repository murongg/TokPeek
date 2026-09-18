import Foundation
import Testing
@testable import TokPeekBridge

@Test("The scanner transport drains reports larger than a pipe buffer")
func largeScannerResponse() throws {
    let process = ReportProcess(
        executableURL: URL(fileURLWithPath: "/bin/sh"),
        arguments: ["-c", "cat >/dev/null; head -c 262144 /dev/zero"]
    )

    let output = try process.run(input: Data(repeating: 42, count: 131_072))

    #expect(output == Data(repeating: 0, count: 262_144))
}

@Test("A scanner crash is reported even if it wrote output")
func scannerFailureIsReported() throws {
    let process = ReportProcess(
        executableURL: URL(fileURLWithPath: "/bin/sh"),
        arguments: ["-c", "cat >/dev/null; printf 'partial report'; exit 7"]
    )

    #expect(throws: (any Error).self) {
        try process.run(input: Data("{}".utf8))
    }
}

@Test("A missing scanner executable fails without waiting for output")
func missingScannerFails() throws {
    let process = ReportProcess(
        executableURL: URL(fileURLWithPath: "/nonexistent/mock-scanner"),
        arguments: []
    )

    #expect(throws: (any Error).self) {
        try process.run(input: Data("{}".utf8))
    }
}
