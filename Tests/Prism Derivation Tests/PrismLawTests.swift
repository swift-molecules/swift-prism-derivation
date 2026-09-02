import Optic
import Prism_Derivation
import Testing

@Test
func prismEmbeddingPreviewsItsPart() {
    let prism = Choice.prisms.message
    #expect(prism.extract(prism.embed("hello")) == "hello")
}

@Test
func prismRejectsEveryOtherCase() {
    #expect(Choice.prisms.message.extract(.empty) == nil)
    #expect(Choice.prisms.empty.extract(.message("hello")) == nil)
}

@Test
func prismPreservesMultipleLabeledValues() {
    let prism = Choice.prisms.count
    let embedded = prism.embed((limit: 3, value: 2))
    let extracted = prism.extract(embedded)
    #expect(extracted?.limit == 3)
    #expect(extracted?.value == 2)
}

@Test
func prismPreservesAnEmptyCase() {
    let prism = Choice.prisms.empty
    let whole = prism.embed(())
    #expect(whole == .empty)
    #expect(prism.extract(whole) != nil)
}

@Test
func prismReembedsAnExtractedPart() throws {
    let prism = Choice.prisms.count
    let whole = Choice.count(limit: 3, value: 2)
    let part = try #require(prism.extract(whole))
    #expect(prism.embed(part) == whole)
}
