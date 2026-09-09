import AccessibilityFixture
func extract(_ node: consuming LinearNode) -> Token? {
    node[dynamicMember: \.leaf]
}
