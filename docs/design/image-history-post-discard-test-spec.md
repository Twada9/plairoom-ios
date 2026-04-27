# 投稿 / 破棄 / やり直し機能 テスト項目表（TDD）

## Context

[image-history-post-discard-design.md](image-history-post-discard-design.md) で承認した実装計画を TDD で進めるための、Red → Green → Refactor サイクル用テスト項目表。

このプロジェクトは **Swift Testing**（`import Testing` / `@Suite` / `@Test` / `#expect`）と TCA の `TestStore` を使用している。既存の [`PLAIROOM-iOSTests/Features/RoomDetail/RoomDetailFeatureTests.swift`](../../PLAIROOM-iOSTests/Features/RoomDetail/RoomDetailFeatureTests.swift) のスタイルを踏襲する。

---

## テスト対象とスコープ

| 対象 | テスト種別 | スコープ |
|---|---|---|
| `ImageHistoryFeature` (Reducer) | TCA TestStore 単体テスト | **本仕様書のメイン**。3 操作（投稿/破棄/やり直し）× 並行 in-flight × エラー文言 |
| `ResultFeature` (Reducer) | TCA TestStore 単体テスト | 既存の post/retry に **discard 系 4 ケース**を追加 |
| `ContentRepository.deleteContent` | DI 契約 | `testValue` の `unimplemented()` 配置のみで担保（明示テスト不要） |
| `ImageContent.Status` 縮小 | コンパイル時保証 | 旧 `.posted` / `.discarded` 参照箇所をコンパイラに発見させる（テストコード不要） |
| `ImageHistoryView` / `ResultView` | スコープ外 | 既存プロジェクトにスナップショット基盤がないため、設計書の手動検証手順で代替 |

---

## ファイル構成（新規 / 追記）

```
PLAIROOM-iOSTests/
├── Features/
│   ├── ImageHistory/
│   │   └── ImageHistoryFeatureTests.swift   ← 新規
│   └── Result/
│       └── ResultFeatureTests.swift         ← 新規（or 既存に追記）
```

---

## ImageHistoryFeature テスト項目表

### A. `items` 算出プロパティ（縮小済み）

| # | テスト名 | 仕様 |
|---|---|---|
| A-1 | `items: ongoingGenerations が空なら空配列` | 初期状態 |
| A-2 | `items: completed 状態の OngoingGeneration のみ ImageContent に変換される` | `subscribing` / `generating` / `failed` は除外 |
| A-3 | `items: 順序が ongoingGenerations の順序を維持する` | `IdentifiedArray` の順序 |
| A-4 | `asImageContent: 返す ImageContent.status は常に .pending` | 不変条件の固定（[OngoingGeneration.swift:54](../../PLAIROOM-iOS/Entity/OngoingGeneration.swift#L54)） |

> A-4 は `OngoingGenerationTests` に置く方が綺麗。`ImageHistoryFeatureTests` で扱う場合は `state.items.allSatisfy { $0.status == .pending }` で間接検証。

### B. `postTapped` 系

| # | テスト名 | 仕様 |
|---|---|---|
| B-1 | `postTapped: processingIds に id を追加し patchStatus(.completed) を呼ぶ` | `state.processingIds == [id]`。依存に `(id, .image, .completed)` で渡る |
| B-2 | `postTapped 成功: operationResponse(.success) → delegate(.generationDismissed) → processingIds が空に戻る` | 順序：state mutation → delegate 発火 |
| B-3 | `postTapped 失敗: alert.title == "投稿に失敗しました"、processingIds が空に戻る、delegate は発火しない` | failure 系 |
| B-4 | `postTapped: 同 id が processingIds に存在する時は patchStatus を呼ばない` | `Issue.record` で検証 |

### C. `discardTapped` 系

| # | テスト名 | 仕様 |
|---|---|---|
| C-1 | `discardTapped: processingIds に id を追加し deleteContent を呼ぶ` | `(id, .image)` で deleteContent が呼ばれる |
| C-2 | `discardTapped 成功: delegate(.generationDismissed) → processingIds が空に戻る` | success 系 |
| C-3 | `discardTapped 失敗: alert.title == "破棄に失敗しました"` | failure 系 |
| C-4 | `discardTapped: 同 id が processingIds に存在する時は deleteContent を呼ばない` | 二重タップ抑止 |

### D. `retryTapped` 系（新規操作）

| # | テスト名 | 仕様 |
|---|---|---|
| D-1 | `retryTapped: processingIds に id を追加し patchStatus(.failed) を呼ぶ` | 依存に `(id, .image, .failed)` で渡る |
| D-2 | `retryTapped 成功: delegate(.generationDismissed) → processingIds が空に戻る` | History の retry も「カードが消える」結果になる |
| D-3 | `retryTapped 失敗: alert.title == "やり直しに失敗しました"` | failure 系 |
| D-4 | `retryTapped: 同 id が processingIds に存在する時は patchStatus を呼ばない` | 二重タップ抑止 |

### E. 並行 in-flight（id 単位の制御）

| # | テスト名 | 仕様 |
|---|---|---|
| E-1 | `別 id の操作は並行可能: postTapped("A") の後 postTapped("B") の両方で patchStatus が呼ばれる` | `processingIds == ["A", "B"]`、依存は 2 回呼ばれる |
| E-2 | `同 id の異種操作も抑止: postTapped("A") 進行中に discardTapped("A") を送っても deleteContent は呼ばれない` | カード単位の disable ポリシーと整合（View 側の `disabled(processingIds.contains(item.id))` の Reducer 等価） |
| E-3 | `A の操作完了後、B はまだ進行中: operationResponse(id: "A") で processingIds == ["B"]` | Set からの remove が id 単位で動くこと |

### F. アラート（具体エラー文言の検証）

| # | テスト名 | 仕様 |
|---|---|---|
| F-1 | `postResponse(.failure(SupabaseError.networkError)): alert.message == "Network Error: ..."` | [SupabaseError.errorDescription](../../PLAIROOM-iOS/API/SupabaseError.swift#L146-L163) のフォーマット検証 |
| F-2 | `postResponse(.failure(SupabaseError.restError)): alert.message == "Supabase Error [code]: msg"` | restError 形式 |
| F-3 | `postResponse(.failure(SupabaseError.unauthorized)): alert.message == "Unauthorized: JWT token is missing or invalid"` | unauthorized 形式 |
| F-4 | `discardResponse(.failure(SupabaseError.networkError)): alert.message == "Network Error: ..."` | 破棄経路でも同じ整形が走ること |
| F-5 | `alert(.dismiss): state.alert == nil` | PresentationAction 経由の dismiss |
| F-6 | `alert dismiss 後、再度 postTapped(id) を送ると正常に開始する` | `processingIds` が空、`alert == nil` の状態で副作用が走ること（リカバリーパスの保証） |

### G. その他（軽い回帰）

| # | テスト名 | 仕様 |
|---|---|---|
| G-1 | `onAppear: state 変化なし、effect なし` | 既存挙動の回帰防止（将来 `onAppear` で副作用を入れる際にこのテストが破られる→意図的な変更を強制できる） |
| G-2 | `selectedTab binding: image を再選択しても状態に影響しない` | 現状タブ 1 つだが将来 `music` 追加時のスモークテスト |

> 旧 G-1（`testValue.deleteContent` の `unimplemented()` 検証）は **削除**。`unimplemented()` の振る舞いは TCA が保証しており、依存差し替え忘れは TestStore 実行時の `unimplemented` クラッシュで自然に検出される。

---

## ResultFeature テスト項目表（追記）

既存の post / retry / cancel 系テストはそのまま維持し、以下を追加する。

### H. `discardButtonTapped` 系

| # | テスト名 | 仕様 |
|---|---|---|
| H-1 | `discardButtonTapped: isRequesting=true、errorMessage=nil、deleteContent を呼ぶ` | `(contentId, room.contentType)` で deleteContent が呼ばれる |
| H-2 | `discardResponse(.success): isRequesting=false、delegate(.discarded) を送出` | 成功時の遷移トリガー |
| H-3 | `discardResponse(.failure(SupabaseError.networkError)): isRequesting=false、errorMessage == "Network Error: ..."` | `RoomDetailFeatureTests` の `testLikeResponseFailureConvertsSupabaseError` と同パターン |
| H-4 | `discardResponse(.failure(SupabaseError.restError)): errorMessage == "Supabase Error [code]: msg"` | restError 経路 |

> ResultFeature は `isRequesting: Bool` の single-flight なので、並行 in-flight テストは不要（History 側の E-1〜E-3 で十分）。

---

## 観点クロスチェック表

各観点が、どのテストでカバーされるかを 1 表にまとめる（実装時のチェックリスト）。

| 観点 | History | Result |
|---|---|---|
| 投稿 successful path | B-2 | 既存 `testPostButtonTappedSuccess` 系 |
| 投稿 failure path（具体エラー） | B-3, F-1〜F-3 | 既存 `testPatchResponseFailure` |
| 破棄 successful path | C-2 | H-2 |
| 破棄 failure path（具体エラー） | C-3, F-4 | H-3, H-4 |
| やり直し successful path | D-2 | 既存 `testRetryButtonTappedSuccess` 系 |
| やり直し failure path | D-3 | 既存 `testPatchResponseFailure` |
| 二重タップ抑止 | B-4, C-4, D-4, E-2 | （single-flight、`disabled` で View が抑止） |
| 並行 in-flight 許容 | E-1, E-3 | — |
| アラート dismiss → 再操作 | F-5, F-6 | （Result は overlay と errorMessage で別経路） |
| Delegate 経路 | B-2, C-2, D-2 | H-2 |
| Effect の cancellable 不在 | （TestStore で store 解放後の send が no-op になることは TCA 側保証 → テスト不要） | 同上 |

---

## TDD 実装順序（Red → Green → Refactor）

各ステップで「失敗するテストを書いてからプロダクションコードを書く」を守る。並行 in-flight テスト（E 系）は最後に書くことで、Reducer の構造的安定後に検証できる。

### ステップ 1: Entity 縮小（コンパイル時保証）
1. **Red**: `Entity/ImageContent.swift` の `Status` から `.posted` / `.discarded` を削除 → `ImageHistoryView.statusBadge` の switch でビルドエラー
2. **Green**: `ImageHistoryView.swift` の switch を `generating` / `pending` の 2 ケースに縮小（旧 ケースの UI コードは削除）
3. **Refactor**: 関連する `// 投稿済み` などのコメント整理

### ステップ 2: Repository 拡張
1. **Red**: テスト C-1 を書こうとする時点で `contentRepository.deleteContent` が無くてビルドエラー
2. **Green**: `Repository/ContentRepository.swift` に `deleteContent` を追加（liveValue / testValue 両方）
3. **Refactor**: `unlikeContent` パターンとの揃えを確認

### ステップ 3: ImageHistoryFeature の State / Action 拡張
1. **A-1, A-2, A-3, A-4** から開始（既存挙動の回帰防止、まだプロダクションコードに変更不要）
2. **B-1**: postTapped で `processingIds` 追加 + `patchStatus` 呼び出し
   - **Red**: `state.processingIds` プロパティが無くビルドエラー
   - **Green**: `processingIds: Set<String>` を State に追加、Reducer に `state.processingIds.insert(id)` + `.run`
3. **B-2**: 成功時の delegate と processingIds remove
4. **B-3 + F-1**: 失敗時の alert
   - **Red**: `state.alert` プロパティが無く、`Action.Alert` enum も無い
   - **Green**: `@Presents var alert`、`Action.alert(PresentationAction<Alert>)`、`.ifLet(\.$alert, action: \.alert)`、failure ハンドラで `AlertState` 構築
5. **B-4**: 二重タップ抑止
6. **C-1〜C-4**: discardTapped を同パターンで実装
7. **D-1〜D-4**: retryTapped を同パターンで実装
8. **E-1〜E-3**: 並行 in-flight（実装上は既に id 単位の `Set` 操作で動くはず → 回帰保証として書く）
9. **F-2〜F-6**: 残るエラー型 / dismiss / リカバリー
10. **G-1, G-2**: 既存挙動の回帰確認

### ステップ 4: ResultFeature 拡張
1. **H-1**: discardButtonTapped で deleteContent を呼ぶ
   - **Red**: `Action.discardButtonTapped` が無くビルドエラー
   - **Green**: Action / Reducer / Delegate に追加
2. **H-2**: 成功時の delegate(.discarded)
3. **H-3, H-4**: 失敗時の errorMessage 変換

### ステップ 5: View 統合（手動検証）
ユニットテストでは到達できない範囲（[image-history-post-discard-design.md の検証手順](image-history-post-discard-design.md#検証手順)）

---

## サンプルコード（参考）

### B-1: postTapped で processingIds に追加し patchStatus を呼ぶ

```swift
@Test("postTapped: processingIdsにidを追加しpatchStatus(.completed)を呼ぶ")
func testPostTappedCallsPatchStatus() async {
    let calledWith = LockIsolated<(String, ContentType, ContentStatus)?>(nil)

    let store = TestStore(initialState: makeStateWithCompletedGeneration(id: "img-1")) {
        ImageHistoryFeature()
    } withDependencies: {
        $0.contentRepository.patchStatus = { id, type, status in
            calledWith.setValue((id, type, status))
        }
    }

    await store.send(.postTapped(id: "img-1")) {
        $0.processingIds = ["img-1"]
    }

    await store.receive(\.operationResponse) {
        $0.processingIds = []
    }

    await store.receive(\.delegate.generationDismissed)

    #expect(calledWith.value?.0 == "img-1")
    #expect(calledWith.value?.1 == .image)
    #expect(calledWith.value?.2 == .completed)
}
```

### E-1: 別 id の操作が並行可能

```swift
@Test("postTapped: 別idの操作は並行可能（両方ともpatchStatusが呼ばれる）")
func testPostTappedAllowsConcurrentDifferentIds() async {
    let callCount = LockIsolated(0)

    let store = TestStore(
        initialState: makeStateWithCompletedGenerations(ids: ["A", "B"])
    ) {
        ImageHistoryFeature()
    } withDependencies: {
        $0.contentRepository.patchStatus = { _, _, _ in
            callCount.withValue { $0 += 1 }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    await store.send(.postTapped(id: "A")) {
        $0.processingIds = ["A"]
    }
    await store.send(.postTapped(id: "B")) {
        $0.processingIds = ["A", "B"]
    }

    await store.receive(\.operationResponse) // どちらか一方
    await store.receive(\.delegate.generationDismissed)
    await store.receive(\.operationResponse) // もう一方
    await store.receive(\.delegate.generationDismissed)

    #expect(callCount.value == 2)
    #expect(store.state.processingIds.isEmpty)
}
```

### F-1: SupabaseError.networkError → "Network Error: ..." に整形

```swift
@Test("postResponse(.failure(SupabaseError.networkError)): alertにNetwork Error文言が入る")
func testPostFailureNetworkErrorMessage() async {
    let supabaseError = SupabaseError.networkError(message: "Network connection failed")

    let store = TestStore(initialState: makeStateWithCompletedGeneration(id: "img-1")) {
        ImageHistoryFeature()
    } withDependencies: {
        $0.contentRepository.patchStatus = { _, _, _ in throw supabaseError }
    }

    await store.send(.postTapped(id: "img-1")) {
        $0.processingIds = ["img-1"]
    }

    await store.receive(\.operationResponse) {
        $0.processingIds = []
        $0.alert = AlertState {
            TextState("投稿に失敗しました")
        } message: {
            TextState("Network Error: Network connection failed")
        }
    }
}
```

### E-2: 同 id の異種操作も抑止

```swift
@Test("postTapped進行中にdiscardTappedしてもdeleteContentは呼ばれない")
func testSameIdCrossOperationIgnored() async {
    let store = TestStore(
        initialState: makeStateWithCompletedGeneration(id: "img-1", processingIds: ["img-1"])
    ) {
        ImageHistoryFeature()
    } withDependencies: {
        $0.contentRepository.deleteContent = { _, _ in
            Issue.record("deleteContent should not be called when same id is processing")
        }
    }

    await store.send(.discardTapped(id: "img-1"))
    // state変化なし、effectなし
}
```

### テストヘルパー（Suite 内 private 関数）

```swift
private func makeStateWithCompletedGeneration(
    id: String,
    processingIds: Set<String> = []
) -> ImageHistoryFeature.State {
    let generation = OngoingGeneration(
        id: "req-\(id)",
        roomId: "room-1",
        contentType: .image,
        prompt: "test",
        createdAt: Date(timeIntervalSince1970: 0),
        status: .completed(fileUrl: "https://example.com/\(id).jpg", contentId: id)
    )
    var state = ImageHistoryFeature.State()
    state.$ongoingGenerations.withLock { $0 = [generation] }
    state.processingIds = processingIds
    return state
}

private func makeStateWithCompletedGenerations(ids: [String]) -> ImageHistoryFeature.State {
    let generations = ids.map { id in
        OngoingGeneration(
            id: "req-\(id)",
            roomId: "room-1",
            contentType: .image,
            prompt: "test",
            createdAt: Date(timeIntervalSince1970: 0),
            status: .completed(fileUrl: "https://example.com/\(id).jpg", contentId: id)
        )
    }
    var state = ImageHistoryFeature.State()
    state.$ongoingGenerations.withLock { $0 = IdentifiedArray(uniqueElements: generations) }
    return state
}
```

> `@Shared` 初期化は `withLock` で行う必要あり（TCA Sharing API の作法）。

### H-2: ResultFeature 破棄成功で delegate(.discarded)

```swift
@Test("discardButtonTapped 成功時: isRequesting=false かつ delegate(.discarded) を送出")
func testDiscardButtonTappedSuccess() async {
    let store = TestStore(initialState: ResultFeature.State(
        contentId: "content-1",
        room: mockRoom
    )) {
        ResultFeature()
    } withDependencies: {
        $0.contentRepository.deleteContent = { _, _ in }
    }

    await store.send(.discardButtonTapped) {
        $0.isRequesting = true
        $0.errorMessage = nil
    }

    await store.receive(\.discardResponse.success) {
        $0.isRequesting = false
    }

    await store.receive(\.delegate.discarded)
}
```

---

## 完了基準

- [ ] `ImageHistoryFeatureTests` が新規作成され、A〜G カテゴリ全テストが Pass
- [ ] `ResultFeatureTests` の H カテゴリが追加され Pass、既存テストも Green を維持
- [ ] `xcodebuild test -scheme PLAIROOM-iOS` で全テスト Green
- [ ] [実装計画書の検証手順](image-history-post-discard-design.md#検証手順) を全て実施（特に手順 4 の並行操作、手順 11 のシート閉鎖中 in-flight）
