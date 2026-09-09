import AccessibilityFixture
import Optic

func apply(_ node: Node<Int>, extract: (Node<Int>) -> Int?) -> Int? { extract(node) }
let payload: Int? = Node.leaf(42).leaf
let absent: Int? = Node<Int>.empty.leaf
let extracted = apply(.leaf(42), extract: \.leaf)
let prism = Node<Int>.prisms.leaf
let composed = Optic<Node<Int>, Node<Int>, Node<Int>, Node<Int>>.Prism.identity.leaf
let plainPrism = Optic<PlainNode, PlainNode, PlainNode, PlainNode>.Prism.identity.leaf

func consumingExtraction(_ node: consuming LinearNode) -> Token? {
    LinearNode.prisms.leaf.extract(node)
}
