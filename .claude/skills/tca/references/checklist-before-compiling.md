## Checklist Before Compiling

- [ ] Every `var body` uses `some Reducer<State, Action>`, not `some ReducerOf<Self>`
- [ ] No `internal import` anywhere in the project
- [ ] Any helper enum used as a labeled associated value in `Action` is defined *outside* `Action`
- [ ] `@Presents` destinations use `.ifLet(\.$destination, action: \.destination)` (dollar-sign prefix)
- [ ] `PresentationAction<T>` is the action type for `@Presents` destinations
- [ ] `PLAIROOM_iOSApp.swift` (or equivalent app entry) passes `store:` argument to the root View
- [ ] `AnyJSON` values accessed via pattern matching, not `.stringValue`
