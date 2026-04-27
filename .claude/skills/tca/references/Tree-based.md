## Tree-Based Navigation with `@Presents`

Use `@Presents` + `@Reducer enum Destination` for all push/modal navigation.
This is the recommended TCA pattern and avoids leaking navigation concerns into
delegate actions.

### Feature side (Reducer)

```swift
@Reducer
struct ParentFeature {

    @ObservableState
    struct State: Equatable {
        // ... domain state ...
        @Presents var destination: Destination.State?
    }

    @Reducer
    enum Destination {
        case child(ChildFeature)
        // add more destinations here
    }

    enum Action {
        // ... domain actions ...
        case destination(PresentationAction<Destination.Action>)
        case somethingTapped
    }

    var body: some Reducer<State, Action> {    // ← explicit generics, NOT ReducerOf<Self>
        Reduce { state, action in
            switch action {
            case .somethingTapped:
                state.destination = .child(ChildFeature.State(...))
                return .none

            case .destination(.presented(.child(.delegate(.done)))):
                state.destination = nil
                return .none

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)   // ← note \.$destination (dollar sign)
    }
}
```

### View side (SwiftUI)

**Push navigation (NavigationStack):**
```swift
NavigationStack {
    List { ... }
        .navigationDestination(
            item: $store.scope(state: \.destination?.child, action: \.destination.child)
        ) { childStore in
            ChildView(store: childStore)
        }
}
```

**Sheet navigation:**
```swift
.sheet(
    item: $store.scope(state: \.destination?.child, action: \.destination.child)
) { childStore in
    ChildView(store: childStore)
}
```

**Global sheet (e.g. Auth modal from AppFeature):**
```swift
// In AppFeature — using @Presents directly on the state field:
@Presents var auth: AuthFeature.State?

// Action uses PresentationAction:
case auth(PresentationAction<AuthFeature.Action>)

// Body:
.ifLet(\.$auth, action: \.auth) { AuthFeature() }

// View:
.sheet(item: $store.scope(state: \.auth, action: \.auth)) { authStore in
    AuthView(store: authStore)
}
```
