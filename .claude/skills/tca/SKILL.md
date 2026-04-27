---
name: tca
description: >
  TCA (The Composable Architecture) development skill for Swift/iOS projects.
  Use this skill whenever writing, editing, or reviewing TCA Reducer code — including
  creating @Reducer structs, defining State/Action, handling navigation with @Presents,
  wiring up dependencies, or debugging macro expansion errors. If the user mentions
  TCA, ComposableArchitecture, @Reducer, @ObservableState, @Presents, BindingReducer,
  Scope, or related patterns, always use this skill.
---

# TCA (The Composable Architecture) Skill

This skill captures hard-won lessons from building a production iOS app with TCA.
Follow these patterns to avoid subtle macro-expansion bugs and navigation pitfalls.

---

## 🚨 Critical Rule #1 — `body` Return Type

**WRONG** — causes `@Reducer` macro circular reference:
```swift
var body: some ReducerOf<Self> { ... }
```

**CORRECT** — always use explicit generic parameters:
```swift
var body: some Reducer<State, Action> { ... }
```

`ReducerOf<Self>` triggers a circular reference in the `@Reducer` macro during
compilation. This error appears on the `@Reducer` line itself, making the root
cause non-obvious. Always write `some Reducer<State, Action>` explicitly.

---

## 🚨 Critical Rule #2 — No `internal import`

Swift 5.9 introduced module-level `internal import`. Linters (like SwiftLint) may
auto-insert lines such as:

```swift
internal import Auth
internal import PostgREST
```

These break `@Reducer` and other macros even in *unrelated* files. If you see an
inexplicable circular-reference or macro-expansion error, check every file for
`internal import` and replace with `import`.

```swift
// WRONG
internal import Supabase

// CORRECT
import Supabase
```

---

## 🚨 Critical Rule #3 — `enum PostAction` Outside `enum Action`

When an `Action` case uses a custom enum as a *labeled* associated value, the
`@CasePathable` macro (synthesized by `@Reducer`) may fail with a circular
reference if the inner enum is nested inside `Action`.

**WRONG:**
```swift
enum Action {
    enum PostAction { case post, retry }          // ← nested inside Action
    case patchResponse(Result<Void, Error>, action: PostAction)
}
```

**CORRECT:**
```swift
/// Defined OUTSIDE Action to avoid @CasePathable circular reference.
enum PostAction { case post, retry }

enum Action {
    case patchResponse(Result<Void, Error>, action: PostAction)
}
```

---

## `AnyJSON` / Supabase `userMetadata` Access

`AnyJSON` (from the Supabase SDK) does NOT have a `.stringValue` property.
Use pattern matching instead:

```swift
// WRONG
let name = user.userMetadata["name"]?.stringValue

// CORRECT
if case let .string(name) = user.userMetadata["name"] {
    state.userName = name
}
```
