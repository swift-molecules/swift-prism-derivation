import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import Prism_Derivation_Macros

private let prismMacros: [String: MacroSpec] = [
    "Prisms": MacroSpec(type: Prism_Derivation_Macros.Macro.self)
]

@Test
func `prism derivation diagnoses a non enum attachment`() {
    assertMacroExpansion(
        """
        @Prisms
        struct Choice {}
        """,
        expandedSource: """
        struct Choice {}
        """,
        diagnostics: [
            DiagnosticSpec(
                message: "@Prisms applies to an enum declaration only.",
                line: 1,
                column: 1
            )
        ],
        macroSpecs: prismMacros,
        failureHandler: { failure in
            Issue.record(Comment(rawValue: failure.message))
        }
    )
}
