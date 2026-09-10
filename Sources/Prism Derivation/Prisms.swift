@_exported import Either
@_exported import Optic

@attached(member, names: arbitrary)
@attached(extension, conformances: __OpticPrismAccessible)
public macro Prisms() = #externalMacro(
    module: "Prism_Derivation_Macros",
    type: "Macro"
)
