public import Prism_Derivation

@Prisms
@dynamicMemberLookup
public enum Node<Value> {
    case leaf(Value)
    case empty
}

@Prisms
public enum PlainNode {
    case leaf(Int)
    case empty
}

public struct Token: ~Copyable {
    public let value: Int
    public init(_ value: Int) { self.value = value }
}

@Prisms
public enum LinearNode: ~Copyable {
    case leaf(Token)
    case empty
}
