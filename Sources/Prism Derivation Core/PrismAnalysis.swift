import SwiftSyntax
import SwiftSyntaxBuilder

struct PrismAnalysis {
    let access: DeclModifierListSyntax
    let cases: [PrismCase]
    let prism: TypeSyntax
    let root: TypeSyntax

    init(
        declaration: EnumDeclSyntax,
        prism: TypeSyntax
    ) throws(PrismDerivation.Diagnostic) {
        guard declaration.genericParameterClause == nil,
              declaration.genericWhereClause == nil
        else {
            throw .init(
                message: "Prisms cannot derive a generic coproduct.",
                node: Syntax(declaration)
            )
        }
        if let modifier = declaration.modifiers.first(where: Self.isUnsupported) {
            throw .init(
                message: "Prisms cannot preserve coproduct isolation or non-access modifiers.",
                node: Syntax(modifier)
            )
        }
        if let attribute = declaration.attributes.first(where: Self.isUnsupported) {
            throw .init(
                message: "Prisms cannot preserve unrelated coproduct attributes or isolation.",
                node: Syntax(attribute)
            )
        }
        if let inheritedType = declaration.inheritanceClause?.inheritedTypes.first(
            where: { $0.type.as(SuppressedTypeSyntax.self) != nil }
        ) {
            throw .init(
                message: "Prisms cannot claim suppressed copyability or escapability.",
                node: Syntax(inheritedType)
            )
        }
        access = Self.access(of: declaration)

        var cases: [PrismCase] = []
        for member in declaration.memberBlock.members {
            guard let caseDeclaration = member.decl.as(EnumCaseDeclSyntax.self) else {
                continue
            }
            guard caseDeclaration.attributes.isEmpty else {
                throw .init(
                    message: "Prisms cannot preserve attributes on individual cases.",
                    node: Syntax(caseDeclaration.attributes)
                )
            }
            for element in caseDeclaration.elements {
                if let parameter = element.parameterClause?.parameters.first(
                    where: { parameter in
                        parameter.type.tokens(viewMode: .sourceAccurate).contains { token in
                            token.tokenKind == .keyword(.Self)
                        }
                    }
                ) {
                    throw .init(
                        message: "Prisms cannot preserve a Self-dependent case value inside the nested prism product.",
                        node: Syntax(parameter)
                    )
                }
                if let parameter = element.parameterClause?.parameters.first(where: {
                    !$0.modifiers.isEmpty
                }) {
                    throw .init(
                        message: "Prisms cannot preserve ownership-qualified case values.",
                        node: Syntax(parameter)
                    )
                }
                cases.append(.init(element))
            }
        }
        let names = cases.map(\.name.text)
        guard Set(names).count == names.count else {
            throw .init(
                message: "Prisms cannot derive overloaded cases because their property names collide.",
                node: Syntax(declaration)
            )
        }
        self.cases = cases
        self.prism = prism
        root = TypeSyntax(IdentifierTypeSyntax(name: declaration.name.trimmed))
    }

    private static func isUnsupported(
        _ element: AttributeListSyntax.Element
    ) -> Bool {
        guard case .attribute(let attribute) = element,
              let name = attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text
        else {
            return true
        }
        return name != "Eliminator" && name != "Prisms"
    }

    private static func isUnsupported(_ modifier: DeclModifierSyntax) -> Bool {
        modifier.name.tokenKind != .keyword(.public)
            && modifier.name.tokenKind != .keyword(.package)
            && modifier.name.tokenKind != .keyword(.internal)
            && modifier.name.tokenKind != .keyword(.private)
            && modifier.name.tokenKind != .keyword(.fileprivate)
            && modifier.name.tokenKind != .keyword(.indirect)
    }

    var expansion: [DeclSyntax] {
        let container = DeclSyntax(
            StructDeclSyntax(
                modifiers: access,
                name: .identifier("Prisms"),
                memberBlock: MemberBlockSyntax(
                    members: MemberBlockItemListSyntax {
                        DeclSyntax("\(access)init() {}")
                        for prismCase in cases {
                            prismCase.property(
                                access: access,
                                root: root,
                                prism: prism
                            )
                        }
                    }
                )
            )
        )
        let value: DeclSyntax = """
            \(access)static var prisms: Prisms { Prisms() }
            """
        return [container, value]
    }

    private static func access(
        of declaration: EnumDeclSyntax
    ) -> DeclModifierListSyntax {
        if declaration.modifiers.contains(where: {
            $0.name.tokenKind == .keyword(.public)
        }) {
            return [.init(name: .keyword(.public, trailingTrivia: .space))]
        }
        if declaration.modifiers.contains(where: {
            $0.name.tokenKind == .keyword(.package)
        }) {
            return [.init(name: .keyword(.package, trailingTrivia: .space))]
        }
        if declaration.modifiers.contains(where: {
            $0.name.tokenKind == .keyword(.fileprivate)
        }) {
            return [.init(name: .keyword(.fileprivate, trailingTrivia: .space))]
        }
        if declaration.modifiers.contains(where: {
            $0.name.tokenKind == .keyword(.private)
        }) {
            return [.init(name: .keyword(.private, trailingTrivia: .space))]
        }
        return []
    }
}
