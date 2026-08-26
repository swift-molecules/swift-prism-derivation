import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct PrismDerivationPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [PrismsMacro.self]
}
