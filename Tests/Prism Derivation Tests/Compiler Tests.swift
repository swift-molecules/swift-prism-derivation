import Foundation
import Testing

@Suite
private struct `Prism accessibility compiler contracts` {
    @Test
    func `public consumers preserve syntax access and ownership boundaries`() throws {
        let files = FileManager.default
        var products = URL(fileURLWithPath: Bundle.module.bundlePath)
        for _ in 0..<12 {
            if files.fileExists(atPath: products.appendingPathComponent("Prism_Derivation.swiftmodule").path)
                || files.fileExists(atPath: products.appendingPathComponent("Modules/Prism_Derivation.swiftmodule").path)
            {
                break
            }
            products.deleteLastPathComponent()
        }
        let plugin = ["Prism Derivation Macros", "Prism Derivation Macros-tool"]
            .map { products.appendingPathComponent($0) }
            .first { files.isExecutableFile(atPath: $0.path) }
        let executable = try #require(plugin, "Could not locate the built prism macro")
        let fixtures = try #require(Bundle.module.resourceURL)
            .appendingPathComponent("Fixtures")
        let scratch = files.temporaryDirectory.appendingPathComponent("prism-compiler-\(UUID().uuidString)")
        try files.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: scratch) }

        let arguments = [
            "-swift-version", "6",
            "-strict-memory-safety",
            "-enable-upcoming-feature", "ExistentialAny",
            "-enable-upcoming-feature", "InternalImportsByDefault",
            "-enable-upcoming-feature", "MemberImportVisibility",
            "-enable-upcoming-feature", "NonisolatedNonsendingByDefault",
            "-enable-upcoming-feature", "InferIsolatedConformances",
            "-enable-experimental-feature", "Lifetimes",
            "-enable-experimental-feature", "MoveOnlyTuples",
            "-module-cache-path", scratch.appendingPathComponent("ModuleCache").path,
            "-I", products.path,
            "-I", products.appendingPathComponent("Modules").path,
            "-I", scratch.path,
            "-load-plugin-executable", executable.path + "#Prism_Derivation_Macros",
        ]
        let library = try compile(arguments + [
            "-emit-module", "-parse-as-library",
            "-module-name", "AccessibilityFixture",
            "-emit-module-path", scratch.appendingPathComponent("AccessibilityFixture.swiftmodule").path,
            fixtures.appendingPathComponent("Accessibility Library.swift").path,
        ])
        try #require(library.status == 0, "Public fixture failed to compile:\n\(library.diagnostic)")

        let cases: [(name: String, diagnostic: String?)] = [
            ("Public Consumer.swift", nil),
            ("Bare Function Member.swift", "has no member 'leaf'"),
            ("Lookup Requires Opt In.swift", "enum case 'leaf' cannot be used as an instance member"),
            ("Lookup Requires Copyable Source.swift", "requires that 'LinearNode' conform to 'Copyable'"),
            ("Lookup Requires Copyable Payload.swift", "requires that 'Token' conform to 'Copyable'"),
        ]
        for fixture in cases {
            let result = try compile(arguments + [
                "-typecheck", "-module-name", "Consumer",
                fixtures.appendingPathComponent(fixture.name).path,
            ])
            if let expected = fixture.diagnostic {
                #expect(result.status != 0, "\(fixture.name) unexpectedly compiled")
                #expect(result.diagnostic.contains(expected), "\(fixture.name):\n\(result.diagnostic)")
                #expect(!result.diagnostic.contains("no such module"))
            } else {
                #expect(result.status == 0, "\(fixture.name):\n\(result.diagnostic)")
            }
        }
    }

    private func compile(_ arguments: [String]) throws -> (status: Int32, diagnostic: String) {
        let process = Process()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["swiftc"] + arguments
        process.standardError = standardError
        try process.run()
        let diagnostic = String(
            decoding: standardError.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        process.waitUntilExit()
        return (process.terminationStatus, diagnostic)
    }
}
