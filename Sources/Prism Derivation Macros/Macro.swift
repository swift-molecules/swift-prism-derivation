import SwiftSyntax
import SwiftSyntaxMacros
import Prism_Derivation_Core

public struct Macro: MemberMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let declaration = declaration.as(EnumDeclSyntax.self) else {
            throw MacroExpansionErrorMessage("@Prisms applies to an enum declaration only.")
        }
        return Prism.Derivation.expansion(of: declaration)
    }
}
