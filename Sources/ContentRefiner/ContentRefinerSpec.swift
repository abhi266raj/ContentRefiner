// SPDX-License-Identifier: AGPL-3.0-only
import AgentAtom

/// Generic successor to script-specific refinement: input stays data, rules stay instructions.
public struct ContentRefinerSpec: ModelledSpec {
    public typealias Input = ContentRefinementInput
    public typealias Output = ContentRefinementOutput
    public static let identity = Identity(id: "ContentRefiner", name: "Content Refiner", version: "0.1.0")
    public static let role = "You are an iterative editor of any textual content: prose, documents, code, scripts, emails, prompts and structured text."
    public let input: Input
    public var output: Output?
    public let instructions: String
    public init(input: Input, instructions: String? = nil) {
        self.input = input
        self.instructions = instructions ?? Self.defaultInstructions
    }
    public static let defaultInstructions = RefinementRules.instructions
}
