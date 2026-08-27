import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros
import Prism_Derivation_Core

public struct PrismsMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enumDeclaration = declaration.as(EnumDeclSyntax.self) else {
            throw DiagnosticsError(
                diagnostics: [
                    .init(
                        node: node,
                        message: PrismMessage(
                            "Prisms attaches to an enum declaration only."
                        )
                    )
                ]
            )
        }
        do throws(PrismDerivation.Diagnostic) {
            let prism = TypeSyntax(
                MemberTypeSyntax(
                    baseType: IdentifierTypeSyntax(
                        name: .identifier("Prism_Derivation")
                    ),
                    period: .periodToken(),
                    name: .identifier("Prism")
                )
            )
            return try PrismDerivation.expansion(
                of: enumDeclaration,
                prism: prism
            )
        } catch {
            throw DiagnosticsError(
                diagnostics: [
                    .init(
                        node: error.node,
                        message: PrismMessage(error.message)
                    )
                ]
            )
        }
    }
}

extension PrismsMacro {
    public static func expansion(
        of _: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(EnumDeclSyntax.self) else { return [] }
        return [
            try ExtensionDeclSyntax(
                "extension \(type.trimmed): Optic_Primitives.__OpticPrismAccessible {}"
            )
        ]
    }
}
