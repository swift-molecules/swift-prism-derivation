import SwiftSyntax
import SwiftSyntaxBuilder

struct PrismCase {
    let name: TokenSyntax
    let parameters: EnumCaseParameterListSyntax

    init(_ element: EnumCaseElementSyntax) {
        name = element.name
        parameters = element.parameterClause?.parameters ?? []
    }

    func property(
        access: DeclModifierListSyntax,
        root: TypeSyntax,
        prism: TypeSyntax
    ) -> DeclSyntax {
        let part = partType
        let embedding = embeddedArguments
        let embeddedValue = parameters.isEmpty ? "_" : "value"
        let pattern = extractionPattern
        let projection = projectedValue
        return """
            \(access)var \(name): \(prism)<\(root), \(part)> {
                \(prism)(
                    embed: { \(raw: embeddedValue) in .\(name)\(raw: embedding) },
                    extract: { whole in
                        guard case .\(name)\(raw: pattern) = whole else { return nil }
                        return \(raw: projection)
                    }
                )
            }
            """
    }

    private var partType: TypeSyntax {
        if parameters.isEmpty {
            return TypeSyntax(
                MemberTypeSyntax(
                    baseType: IdentifierTypeSyntax(name: .identifier("Swift")),
                    period: .periodToken(),
                    name: .identifier("Void")
                )
            )
        }
        if parameters.count == 1 {
            return parameters[parameters.startIndex].type
        }
        let elements = parameters.map { parameter in
            guard let label = label(of: parameter) else {
                return parameter.type.trimmedDescription
            }
            return "\(label.trimmedDescription): \(parameter.type.trimmedDescription)"
        }.joined(separator: ", ")
        return TypeSyntax("(\(raw: elements))")
    }

    private var embeddedArguments: String {
        guard !parameters.isEmpty else {
            return ""
        }
        if parameters.count == 1 {
            let parameter = parameters[parameters.startIndex]
            guard let label = label(of: parameter) else {
                return "(value)"
            }
            return "(\(label.trimmedDescription): value)"
        }
        let values = parameters.enumerated().map { index, parameter in
            guard let label = label(of: parameter) else {
                return "value.\(index)"
            }
            return "\(label.trimmedDescription): value.\(index)"
        }.joined(separator: ", ")
        return "(\(values))"
    }

    private var extractionPattern: String {
        guard !parameters.isEmpty else {
            return ""
        }
        let bindings = parameters.enumerated().map { index, parameter in
            guard let label = label(of: parameter) else {
                return "let value\(index)"
            }
            return "\(label.trimmedDescription): let value\(index)"
        }.joined(separator: ", ")
        return "(\(bindings))"
    }

    private var projectedValue: String {
        guard !parameters.isEmpty else {
            return "()"
        }
        if parameters.count == 1 {
            return "value0"
        }
        let values = parameters.enumerated().map { index, parameter in
            guard let label = label(of: parameter) else {
                return "value\(index)"
            }
            return "\(label.trimmedDescription): value\(index)"
        }.joined(separator: ", ")
        return "(\(values))"
    }

    private func label(
        of parameter: EnumCaseParameterSyntax
    ) -> TokenSyntax? {
        guard let name = parameter.firstName, name.text != "_" else {
            return nil
        }
        return name
    }
}
