public import SwiftSyntax

public enum PrismDerivation {
    public static func expansion(
        of declaration: EnumDeclSyntax,
        prism: TypeSyntax
    ) throws(Diagnostic) -> [DeclSyntax] {
        try PrismAnalysis(declaration: declaration, prism: prism).expansion
    }
}
