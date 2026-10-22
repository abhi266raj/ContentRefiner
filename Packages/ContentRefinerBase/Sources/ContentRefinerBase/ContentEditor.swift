// SPDX-License-Identifier: AGPL-3.0-only
import SwiftCrossUI

/// A bounded editor with independent scrolling for long drafts and instructions.
public struct ContentEditor: View {
    @Binding private var text: String
    private let height: Int
    public init(text: Binding<String>, height: Int) { _text = text; self.height = height }
    public var body: some View {
        ScrollView {
            TextEditor(text: $text).frame(minHeight: max(1, height - 16), alignment: .topLeading).padding(8)
        }
        .frame(height: height)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
