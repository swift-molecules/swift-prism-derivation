@_exported import Either
@_exported import Optic

@attached(member, names: arbitrary)
public macro Prisms() = #externalMacro(
    module: "Prism_Derivation_Macros",
    type: "Macro"
)
