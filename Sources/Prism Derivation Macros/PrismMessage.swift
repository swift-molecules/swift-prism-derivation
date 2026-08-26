import SwiftDiagnostics

struct PrismMessage: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(
        domain: "PrismDerivation",
        id: "unsupported-coproduct"
    )
    let severity = DiagnosticSeverity.error

    init(_ message: String) {
        self.message = message
    }
}
