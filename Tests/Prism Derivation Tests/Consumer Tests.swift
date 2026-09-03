import Prism_Derivation
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

    // Merely forming this prism forces the nested generic-reference analysis.
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
