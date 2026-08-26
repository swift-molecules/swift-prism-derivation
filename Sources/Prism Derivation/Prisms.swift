@attached(member, names: named(Prisms), named(prisms))
public macro Prisms() = #externalMacro(
    module: "Prism_Derivation_Macros",
    type: "PrismsMacro"
)
