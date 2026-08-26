public import Prism_Derivation

@Prisms
public enum Choice: Equatable {
    case message(String)
    case count(limit: Int, value: Int)
    case empty
}
