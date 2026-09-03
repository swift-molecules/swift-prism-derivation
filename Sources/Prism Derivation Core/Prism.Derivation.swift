public import SwiftSyntax
public import Coproduct_Derivation_Core
import SwiftSyntaxBuilder

extension Prism {
    public enum Derivation {
        public static func expansion(
            of declaration: EnumDeclSyntax
        ) -> [DeclSyntax] {
            expansion(Coproduct.Analysis(declaration))
        }

        public static func expansion(
            whole: TypeSyntax,
            access: DeclModifierSyntax?,
            cases: [EnumCaseElementSyntax],
            genericParameter: TokenSyntax?
        ) -> [DeclSyntax] {
            expansion(
                Coproduct.Analysis(
                    whole: whole,
                    access: access,
                    cases: cases,
                    genericParameter: genericParameter
                )
            )
        }

        public static func expansion(_ analysis: Coproduct.Analysis) -> [DeclSyntax] {
            let access = analysis.access.map { "\($0.name.text) " } ?? ""
            var properties = analysis.cases.map {
                property($0, analysis: analysis, access: access)
            }
            if let rawType = rawType(of: analysis) {
                properties.append(
                    rawValueProperty(
                        whole: analysis.whole.trimmedDescription,
                        rawType: rawType,
                        access: access
                    )
                )
            }
            let members = properties.joined(separator: "\n")

            return ["""
                \(raw: access)struct Prisms {
                    \(raw: members)
                }

                \(raw: access)static var prisms: Prisms {
                    Prisms()
                }
                """]
        }

        private static func rawType(of analysis: Coproduct.Analysis) -> String? {
            guard
                let inherited = analysis.declaration?
                    .inheritanceClause?.inheritedTypes.first?.type,
                let identifier = inherited.as(IdentifierTypeSyntax.self),
                identifier.moduleSelector == nil,
                identifier.genericArgumentClause == nil
            else { return nil }

            let standardRawTypes: Set<String> = [
                "Character", "String",
                "Int", "Int8", "Int16", "Int32", "Int64",
                "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
                "Float", "Double",
            ]
            guard standardRawTypes.contains(identifier.name.text) else {
                return nil
            }
            return inherited.trimmedDescription
        }

        private static func rawValueProperty(
            whole: String,
            rawType: String,
            access: String
        ) -> String {
            """
            /// Matches the enum's semantic raw-value representation.
            ///
            /// - Law: Lawfulness relies on the semantic `RawRepresentable`
            ///   round-trip contract, which Swift does not mechanically enforce.
            \(access)var rawValue: Optic<
                \(rawType),
                \(rawType),
                \(whole),
                \(whole)
            >.Prism {
                .init(
                    match: { rawValue in
                        guard let represented = \(whole)(rawValue: rawValue) else {
                            return .left(rawValue)
                        }
                        return .right(represented)
                    },
                    embed: { $0.rawValue }
                )
            }
            """
        }

        private static func property(
            _ coproductCase: Coproduct.Analysis.Case,
            analysis: Coproduct.Analysis,
            access: String
        ) -> String {
            let name = coproductCase.name.text
            let whole = analysis.whole.trimmedDescription
            let payload = coproductCase.payload.trimmedDescription

            switch coproductCase.parameters.count {
            case 0:
                return """
                    \(access)var \(name): Optic<\(whole), \(whole), Void, Void>.Prism {
                        .init(
                            match: { whole in
                                \(matchBody(for: coproductCase, in: analysis, consuming: "whole"))
                            },
                            embed: { _ in .\(name) }
                        )
                    }
                    """
            case 1:
                var declaration = """
                    \(access)var \(name): Optic<\(whole), \(whole), \(payload), \(payload)>.Prism {
                        .init(
                            match: { whole in
                                \(matchBody(for: coproductCase, in: analysis, consuming: "whole"))
                            },
                            embed: { .\(name)(\(constructorArgument("$0", at: 0, in: coproductCase))) }
                        )
                    }
                    """
                if
                    let parameter = analysis.genericParameter,
                    coproductCase.isDirectReference(to: parameter),
                    analysis.cases
                        .filter({ $0.name.text != name })
                        .allSatisfy({ !$0.references(parameter) })
                {
                    declaration += """

                        \(access)func \(name)<Replacement>(
                            to _: Replacement.Type
                        ) -> Optic<
                            \(whole)<\(parameter.text)>,
                            \(whole)<Replacement>,
                            \(parameter.text),
                            Replacement
                        >.Prism {
                            .init(
                                match: { whole in
                                    \(matchBody(for: coproductCase, in: analysis, consuming: "whole"))
                                },
                                embed: { .\(name)(\(constructorArgument("$0", at: 0, in: coproductCase))) }
                            )
                        }
                        """
                }
                return declaration
            default:
                let embed: String
                if analysis.isCopyableSuppressed {
                    let projectedArguments = coproductCase.parameters.indices.map {
                        constructorArgument("payload.\($0)", at: $0, in: coproductCase)
                    }
                    embed = """
                        { (payload: consuming \(payload)) in
                            .\(name)(\(projectedArguments.joined(separator: ", ")))
                        }
                        """
                } else {
                    let projectedArguments = coproductCase.parameters.indices.map {
                        constructorArgument("$0.\($0)", at: $0, in: coproductCase)
                    }
                    embed = "{ .\(name)(\(projectedArguments.joined(separator: ", "))) }"
                }
                return """
                    \(access)var \(name): Optic<\(whole), \(whole), \(payload), \(payload)>.Prism {
                        .init(
                            match: { whole in
                                \(matchBody(for: coproductCase, in: analysis, consuming: "whole"))
                            },
                            embed: \(embed)
                        )
                    }
                    """
            }
        }

        private static func matchBody(
            for selected: Coproduct.Analysis.Case,
            in analysis: Coproduct.Analysis,
            consuming value: String
        ) -> String {
            let branches = analysis.cases.map { coproductCase in
                coproductCase.name.text == selected.name.text
                    ? matchingBranch(coproductCase)
                    : unmatchedBranch(coproductCase)
            }.joined(separator: "\n")
            let switchValue = analysis.isCopyableSuppressed
                ? "consume \(value)"
                : value
            return """
                switch \(switchValue) {
                \(branches)
                }
                """
        }

        private static func matchingBranch(
            _ coproductCase: Coproduct.Analysis.Case
        ) -> String {
            let name = coproductCase.name.text
            switch coproductCase.parameters.count {
            case 0:
                return "case .\(name): return .right(())"
            case 1:
                return "case let .\(name)(value): return .right(value)"
            default:
                let values = coproductCase.parameters.indices.map { "value\($0)" }
                return "case let .\(name)(\(values.joined(separator: ", "))): return .right((\(tupleExpression(values, in: coproductCase))))"
            }
        }

        private static func unmatchedBranch(
            _ coproductCase: Coproduct.Analysis.Case
        ) -> String {
            let name = coproductCase.name.text
            guard !coproductCase.parameters.isEmpty else {
                return "case .\(name): return .left(.\(name))"
            }
            let values = coproductCase.parameters.indices.map { "value\($0)" }
            let arguments = values.enumerated().map { offset, value in
                constructorArgument(value, at: offset, in: coproductCase)
            }
            return "case let .\(name)(\(values.joined(separator: ", "))): return .left(.\(name)(\(arguments.joined(separator: ", "))))"
        }

        private static func constructorArgument(
            _ value: String,
            at offset: Int,
            in coproductCase: Coproduct.Analysis.Case
        ) -> String {
            coproductCase.constructorLabel(at: offset).map {
                "\($0.text): \(value)"
            } ?? value
        }

        private static func tupleExpression(
            _ values: [String],
            in coproductCase: Coproduct.Analysis.Case
        ) -> String {
            values.enumerated().map { offset, value in
                coproductCase.tupleLabel(at: offset).map {
                    "\($0.text): \(value)"
                } ?? value
            }.joined(separator: ", ")
        }
    }
}
