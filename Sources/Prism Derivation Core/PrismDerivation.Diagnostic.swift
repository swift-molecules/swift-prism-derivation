public import SwiftSyntax

extension PrismDerivation {
    public struct Diagnostic: Swift.Error {
        public let message: String
        public let node: Syntax

        init(message: String, node: Syntax) {
            self.message = message
            self.node = node
        }
    }
}
