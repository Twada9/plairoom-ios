//
//  ImageDetailFeature.swift
//  PLAIROOM-iOS
//

import ComposableArchitecture
import Foundation

@Reducer
struct ImageDetailFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        let item: ContentItem
    }

    // MARK: - Action

    enum Action {}

    // MARK: - Body

    var body: some Reducer<State, Action> {
        Reduce { _, _ in .none }
    }
}
