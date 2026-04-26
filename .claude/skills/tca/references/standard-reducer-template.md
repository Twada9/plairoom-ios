## Standard Reducer Template

Use this as a starting point for every new Feature:

```swift
import ComposableArchitecture
import Foundation

@Reducer
struct MyFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        // ...
    }

    // MARK: - Action

    enum Action: BindableAction {          // omit BindableAction if no @Bindable fields
        case binding(BindingAction<State>) // omit if not using BindingReducer
        case onAppear
        // ...
        case delegate(Delegate)

        enum Delegate {
            // delegate actions sent UP to the parent
        }
    }

    // MARK: - Dependencies

    @Dependency(\.someClient) var someClient

    // MARK: - Body

    var body: some Reducer<State, Action> {    // ← ALWAYS explicit generics
        BindingReducer()                       // omit if not using bindings
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .onAppear:
                return .none
            case .delegate:
                return .none
            }
        }
    }
}
```
