public import Prism_Derivation
import Testing

@Prisms
private enum Choice {
    case none
    case name(String)
    case pair(Int, String)
    case labeled(code: Int, note: String)
}

@Prisms
private enum GenericChoice<Value> {
    case value(payload: Value)
    case empty
}

private enum Qualified {
    struct Value {}
}

@Prisms
private enum NameCollision<Value> {
    case value(Value)
    case qualified(Qualified.Value)
}

@Prisms
private enum NestedReference<Value> {
    case value(Value)
    case retained([Value])
}

private struct LinearToken: ~Copyable {
    let value: Int
}

@Prisms
private enum LinearPair: ~Copyable {
    case pair(LinearToken, LinearToken)
    case empty
}

@Prisms
private enum RawChoice: Int {
    case one = 1
    case two = 2
}

@Test
func `derived prisms embed extract and reject other cases`() {
    guard case .right = Choice.prisms.none.match(.none) else {
        Issue.record("Expected none to match")
        return
    }
    guard case let .right(name) = Choice.prisms.name.match(.name("Blob")) else {
        Issue.record("Expected name to match")
        return
    }
    #expect(name == "Blob")
    guard case .left(.none) = Choice.prisms.name.match(.none) else {
        Issue.record("Expected none to reconstruct through a name mismatch")
        return
    }

    let pair = Choice.prisms.pair.embed((42, "Blob"))
    guard case let .pair(number, name) = pair else {
        Issue.record("Expected pair")
        return
    }
    #expect(number == 42)
    #expect(name == "Blob")

    let labeled = Choice.prisms.labeled.embed((code: 7, note: "seven"))
    guard case let .labeled(code, note) = labeled else {
        Issue.record("Expected labeled payload")
        return
    }
    #expect(code == 7)
    #expect(note == "seven")
}

@Test
func `derived prism transforms a generic family`() {
    let prism = GenericChoice<Int>.prisms.value(to: String.self)

    guard case let .right(value) = prism.match(.value(payload: 42)) else {
        Issue.record("Expected value to match")
        return
    }
    #expect(value == 42)
    guard case .value(payload: "forty-two") = prism.embed("forty-two") else {
        Issue.record("Expected replacement to embed in the target family")
        return
    }
    guard case .left(.empty) = prism.match(.empty) else {
        Issue.record("Expected empty to reconstruct in the target family")
        return
    }
}

@Test
func `type changing prism distinguishes a generic reference from a member name`() {
    let prism = NameCollision<Int>.prisms.value(to: String.self)

    guard case .left(.qualified) = prism.match(.qualified(Qualified.Value())) else {
        Issue.record("Expected the generic-independent case to reconstruct")
        return
    }
    guard case .value("replacement") = prism.embed("replacement") else {
        Issue.record("Expected the replacement generic argument")
        return
    }
}

@Test
func `prism match and embed obey partial round trip laws`() {
    let embedded = Choice.prisms.labeled.embed((code: 42, note: "Blob"))
    guard case let .right(payload) = Choice.prisms.labeled.match(embedded) else {
        Issue.record("Expected an embedded focus to match")
        return
    }
    #expect(payload.code == 42)
    #expect(payload.note == "Blob")

    let rejected = Choice.pair(7, "seven")
    guard case let .left(.pair(number, word)) = Choice.prisms.labeled.match(rejected) else {
        Issue.record("Expected a rejected source to be reconstructed")
        return
    }
    #expect(number == 7)
    #expect(word == "seven")

    _ = NestedReference<Int>.prisms.value
}

@Test
func `derived prism carries a noncopyable tuple payload`() {
    let embedded = LinearPair.prisms.pair.embed(
        (LinearToken(value: 1), LinearToken(value: 2))
    )
    let matched = LinearPair.prisms.pair.match(embedded)

    switch consume matched {
    case .right:
        break
    case .left:
        Issue.record("Expected the noncopyable tuple payload to match")
    }
}

@Test
func `raw enum derives its nominal raw-value prism`() {
    let prism = RawChoice.prisms.rawValue

    guard case .right(.one) = prism.match(1) else {
        Issue.record("Expected a represented raw value to match")
        return
    }
    guard case .left(3) = prism.match(3) else {
        Issue.record("Expected an invalid raw value to remain available")
        return
    }
    #expect(prism.embed(.two) == 2)
}

@Prisms
@dynamicMemberLookup
private enum Node {
    case leaf(Int)
    case empty
}

@Prisms
private enum Branch {
    case node(Node)
    case empty
}

@Prisms
@dynamicMemberLookup
public enum PublicNode<Value> {
    case leaf(Value)
    case empty
}

@Prisms
@dynamicMemberLookup
package enum PackageNode {
    case leaf(Int)
    case empty
}

private enum Namespace {
    @Prisms
    @dynamicMemberLookup
    enum Node<Value> {
        case leaf(Value)
        case empty
    }
}

@Prisms
@dynamicMemberLookup
private enum PropertyCollision {
    case leaf(Int)
    case empty

    var leaf: String { "existing property" }
    var description: String { "description" }
    var prisms: String { "instance prisms" }
}

@Prisms
@dynamicMemberLookup
private enum RawDynamicChoice: Int {
    case one = 1
    case two = 2
}

@Test
func `dynamic members extract matching cases and preserve their source`() {
    let node = Node.leaf(42)
    let value: Int? = node.leaf
    #expect(value == 42)
    #expect(node.leaf == 42)
    #expect(Node.empty.leaf == nil)
    #expect(Node.empty.empty != nil)
    #expect(node.empty == nil)
}

@Test
func `dynamic member key paths convert to extraction functions`() {
    func apply(_ node: Node, extract: (Node) -> Int?) -> Int? {
        extract(node)
    }
    #expect(apply(.leaf(42), extract: \.leaf) == 42)
    #expect(apply(.empty, extract: \.leaf) == nil)
    let extract: (Node) -> Int? = \Node.leaf
    #expect(extract(.leaf(7)) == 7)
}

@Test
func `generic and nested enums retain dynamic member access`() {
    #expect(PublicNode.leaf(42).leaf == 42)
    #expect(PublicNode<String>.empty.leaf == nil)
    #expect(PackageNode.leaf(7).leaf == 7)
    #expect(Namespace.Node.leaf("nested").leaf == "nested")
    #expect(GenericChoice<Int>.prisms.value.extract(.value(payload: 42)) == 42)
}

@Test
func `existing properties take precedence over dynamic extraction`() {
    let node = PropertyCollision.leaf(42)
    #expect(node.leaf == "existing property")
    #expect(node.description == "description")
    #expect(node.prisms == "instance prisms")
    #expect(PropertyCollision.prisms.leaf.extract(node) == 42)
    #expect(node[dynamicMember: \.leaf] == 42)
    #expect(RawDynamicChoice.one.rawValue == 1)
    #expect(RawDynamicChoice.one.one != nil)
}

@Test
func `derived accessibility composes without opting into instance lookup`() {
    let root = Optic<Branch, Branch, Branch, Branch>.Prism.identity
    let leaf = root.node.leaf
    #expect(leaf.extract(.node(.leaf(42))) == 42)
    #expect(leaf.extract(.node(.empty)) == nil)
    #expect(leaf.extract(.empty) == nil)
    #expect(Branch.prisms.node.extract(leaf.embed(7))?.leaf == 7)
}

@Test
func `noncopyable derivation retains consuming extraction and accessibility`() {
    func collection<Value: ~Copyable & __OpticPrismAccessible>(_: Value.Type) -> Value.Prisms {
        Value.prisms
    }
    let prisms = collection(LinearPair.self)
    let extracted = prisms.pair.extract(.pair(LinearToken(value: 1), LinearToken(value: 2)))
    switch consume extracted {
    case .some:
        break
    case .none:
        Issue.record("Expected consuming extraction to preserve the linear payload")
    }
    let rejected = prisms.pair.match(.empty)
    switch consume rejected {
    case .left(.empty): break
    default: Issue.record("Expected a noncopyable mismatch to reconstruct the source")
    }
}

@Prisms
@dynamicMemberLookup
private enum AlreadyAccessible {
    case leaf(Int)
    case empty
}

extension AlreadyAccessible: Optic<AlreadyAccessible, AlreadyAccessible, Int, Int>.Prism.Accessible {}

@Test
func `derivation respects an existing accessibility conformance`() {
    #expect(AlreadyAccessible.leaf(42).leaf == 42)
}

@Prisms
private enum GenericLinear<Value: ~Copyable>: ~Copyable {
    case value(Value)
    case empty
}

@Test
func `accessibility does not constrain a noncopyable generic payload`() {
    let prism = GenericLinear<LinearToken>.prisms.value
    let source = prism.embed(LinearToken(value: 42))
    let extracted = prism.extract(source)
    switch consume extracted {
    case let .some(token): #expect(token.value == 42)
    case .none: Issue.record("Expected the generic noncopyable payload")
    }
}
