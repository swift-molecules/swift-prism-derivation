import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import Prism_Derivation_Macros

private let prismMacros: [String: MacroSpec] = [
    "Prisms": MacroSpec(
        type: Prism_Derivation_Macros.Macro.self,
        conformances: ["__OpticPrismAccessible"]
    )
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

@Test
func `prism derivation adds accessibility and preserves explicit dynamic lookup`() {
    assertMacroExpansion(
        """
        @Prisms
        @dynamicMemberLookup
        public enum Node {
            case leaf(Int)
        }
        """,
        expandedSource: """
        @dynamicMemberLookup
        public enum Node {
            case leaf(Int)

            public struct Prisms {
                public var leaf: Optic<Node, Node, Int, Int>.Prism {
                .init(
                    match: { whole in
                        switch whole {
                        case let .leaf(value):
                            return .right(value)
                        }
                    },
                    embed: {
                        .leaf($0)
                    }
                )
                }
            }

            public static var prisms: Prisms {
                Prisms()
            }
        }

        extension Node: __OpticPrismAccessible {
        }
        """,
        macroSpecs: prismMacros,
        failureHandler: { failure in
            Issue.record(Comment(rawValue: failure.message))
        }
    )
}

@Test
func `prism derivation does not opt into dynamic lookup or copyability`() {
    assertMacroExpansion(
        """
        @Prisms
        enum Linear: ~Copyable {}
        """,
        expandedSource: """
        enum Linear: ~Copyable {

            struct Prisms {

            }

            static var prisms: Prisms {
                Prisms()
            }
        }

        extension Linear: __OpticPrismAccessible {
        }
        """,
        macroSpecs: prismMacros,
        failureHandler: { failure in
            Issue.record(Comment(rawValue: failure.message))
        }
    )
}
