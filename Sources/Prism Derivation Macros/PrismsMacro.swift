import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

public struct PrismsMacro: MemberMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingMembersOf _: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

@main
struct PrismDerivationPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [PrismsMacro.self]
}
