@_exported import Either
@_exported import Optic

/// Derives the enum's prisms and `Optic.Prism.Accessible` conformance.
///
/// Add `@dynamicMemberLookup` explicitly to enable `node.leaf` extraction.
/// For a `(Node) -> Int?` parameter, pass `\Node.leaf` or `\.leaf`.
/// Swift does not support bare `.leaf` as a function value.
/// Dynamic-member extraction requires a copyable enum and payload; consuming
/// operations on `Node.prisms.leaf` remain available for noncopyable values.
/// With internal imports by default, use `public import Prism_Derivation` when
/// deriving prisms for a public enum.
@attached(member, names: arbitrary)
@attached(extension, conformances: __OpticPrismAccessible)
public macro Prisms() = #externalMacro(
    module: "Prism_Derivation_Macros",
    type: "Macro"
)
