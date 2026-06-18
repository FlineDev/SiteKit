import SwiftSyntax

/// Walks a parsed Swift tree and assigns a refined semantic role to every identifier-ish token
/// that the out-of-the-box `SwiftIDEUtils` classification leaves as a generic `identifier`.
///
/// The base classification already separates keywords, strings, numbers, comments, attributes,
/// operators, argument labels, and identifiers that appear in TYPE position. What it cannot do is
/// tell apart the different roles a generic identifier plays in EXPRESSION position – a type
/// initializer (`ScrollView`), a function call (`print`), a member (`.swipeActions`), a value
/// reference (`stickers`), or a parameter binding (`sticker`). That distinction is what gives the
/// Xcode-like palette its green variable references, so this visitor supplies it from the tree
/// structure (no type-checker or symbol graph required).
///
/// The result is a map from a token's content start (its UTF-8 byte offset, after leading trivia)
/// to a `sk-tok-*` role class. `SwiftSyntaxHighlighter` consults this map first and falls back to
/// the base classification for every token the visitor did not refine.
///
/// Priority is handled by tree order: a parent node (a call, a member access) assigns the
/// authoritative role for the identifier it owns BEFORE the generic `DeclReferenceExpr` visitor
/// reaches that same identifier as a child, and the generic visitor only fills offsets that are
/// still unset.
final class SwiftTokenRoleClassifier: SyntaxVisitor {
   /// Byte offset of a token's content start → its refined `sk-tok-*` role class.
   private(set) var roles: [Int: String] = [:]

   /// Classifies every refinable token in `tree` and returns the offset→role map.
   static func classify(_ tree: SourceFileSyntax) -> [Int: String] {
      let visitor = SwiftTokenRoleClassifier(viewMode: .sourceAccurate)
      visitor.walk(tree)
      return visitor.roles
   }

   // MARK: - Helpers

   private func byteOffset(of token: TokenSyntax) -> Int {
      token.positionAfterSkippingLeadingTrivia.utf8Offset
   }

   /// Records `role` for `token`. `overwrite: false` only fills an offset the visitor has not yet
   /// classified, so a specific parent assignment is never clobbered by the generic fallback.
   private func set(_ role: String, at token: TokenSyntax, overwrite: Bool = true) {
      let offset = self.byteOffset(of: token)
      if overwrite || self.roles[offset] == nil {
         self.roles[offset] = role
      }
   }

   private func isIdentifierToken(_ token: TokenSyntax) -> Bool {
      if case .identifier = token.tokenKind { return true }
      return false
   }

   private func startsUppercased(_ text: String) -> Bool {
      guard let first = text.first else { return false }
      return first.isUppercase
   }

   // MARK: - Calls

   override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
      // The callee identifies what kind of call this is. A capitalized callee is a type initializer
      // (`ScrollView { … }`, `ForEach(…)`, `StickerListItemView(…)`) and takes the `type` role. A
      // lowercase callee is a free-function call (`print(…)`). A member callee (`view.swipeActions(…)`)
      // is left to the member-access visitor so the member keeps its `member` role whether or not it
      // is called.
      if let reference = node.calledExpression.as(DeclReferenceExprSyntax.self),
         self.isIdentifierToken(reference.baseName) {
         let role = self.startsUppercased(reference.baseName.text) ? "type" : "call"
         self.set(role, at: reference.baseName)
      }
      return .visitChildren
   }

   // MARK: - Member access

   override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
      // The member name in `base.member` (or a leading-dot member like `.trailing`). Classified
      // `member` regardless of whether it is then called, matching Xcode where `.swipeActions`
      // stays the default member color.
      let name = node.declName.baseName
      if self.isIdentifierToken(name) {
         self.set("member", at: name)
      }
      return .visitChildren
   }

   // MARK: - Generic value references

   override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
      // Reached for every declaration reference. Callees and member names were already assigned
      // by their parent above, so only fill the ones still unset: a lowercase reference is a value
      // (`stickers`, `sticker`) → the headline green `variable`; a capitalized one is a bare type
      // reference (`Color.red`'s `Color`, a metatype) → the `type` role.
      let token = node.baseName
      guard self.isIdentifierToken(token) else { return .visitChildren }
      let offset = self.byteOffset(of: token)
      guard self.roles[offset] == nil else { return .visitChildren }
      self.roles[offset] = self.startsUppercased(token.text) ? "type" : "variable"
      return .visitChildren
   }

   // MARK: - Parameter and binding declarations

   override func visit(_ node: ClosureShorthandParameterSyntax) -> SyntaxVisitorContinueKind {
      // The `sticker` in `{ sticker in … }`.
      self.set("param", at: node.name)
      return .visitChildren
   }

   override func visit(_ node: ClosureParameterSyntax) -> SyntaxVisitorContinueKind {
      // The name in a typed closure parameter `{ (sticker: Sticker) in … }`.
      self.set("param", at: node.firstName)
      return .visitChildren
   }

   override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
      // The internal binding name of a function parameter (`func add(to list: …)` → `list`). The
      // external label (`firstName`) is already classified `argumentLabel` by the base pass.
      if let secondName = node.secondName {
         self.set("param", at: secondName)
      }
      return .visitChildren
   }

   override func visit(_ node: IdentifierPatternSyntax) -> SyntaxVisitorContinueKind {
      // A value binding name: `let name = …`, `for sticker in …`, `case let .some(value)`. Colored
      // like a value reference (green) since it names a value the reader will then refer to.
      self.set("variable", at: node.identifier)
      return .visitChildren
   }

   // MARK: - Boolean and nil literals

   override func visit(_ node: BooleanLiteralExprSyntax) -> SyntaxVisitorContinueKind {
      // `true` / `false` arrive as keyword tokens; lift them into their own `boolean` role.
      self.set("boolean", at: node.literal)
      return .visitChildren
   }

   override func visit(_ node: NilLiteralExprSyntax) -> SyntaxVisitorContinueKind {
      // `nil` is grouped with the booleans per the palette spec.
      self.set("boolean", at: node.nilKeyword)
      return .visitChildren
   }
}
