@attached(member, names: named(Prisms), named(prisms))
@attached(
    extension,
    conformances: Optic::__OpticPrismAccessible,
    names: arbitrary
)
public macro Prisms() = #externalMacro(
    module: "Prism_Derivation_Macros",
    type: "PrismsMacro"
)
