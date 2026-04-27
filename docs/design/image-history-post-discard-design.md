# 生成画像の投稿 / 破棄 / やり直し機能の実装

## Context

`ImageHistoryView` の「投稿する」「破棄」ボタン、`ResultView` の「投稿する」「やり直す」ボタンが部分実装で TODO のまま。今回は両 Feature の操作セットを **「投稿する / 破棄 / やり直す」の3種類に揃え、API 呼び出しまで完成させる**。

合わせて以下を行う：

- `ImageContent.Status` の dead enum 値（`posted` / `discarded`）を **削除**（rename ではない）
- `ContentRepository.deleteContent`（DELETE 用）を新規追加
- `ImageHistoryFeature` を **id 単位の並行 in-flight 許容**（同 id の二重タップだけ抑止）に拡張

`ResultFeature` がほぼ同等の参照モデルとなる（[ResultFeature.swift:68-103](../../PLAIROOM-iOS/Features/Result/ResultFeature.swift#L68-L103)）。

---

## 操作と API の対応表

3 操作（投稿 / 破棄 / やり直す）を **両 Feature に揃える**。API 側の作用（PATCH/DELETE）は同じだが、UI 遷移は異なる。

| 操作 | API 呼び出し | 意味 | `ResultFeature` の遷移 | `ImageHistoryFeature` の挙動 |
|---|---|---|---|---|
| 投稿する | `patchStatus(id, type, .completed)` | 公開確定 | RoomDetail へ戻る (`.posted`) | カードがリストから消える |
| やり直す | `patchStatus(id, type, .failed)` | 失敗扱い、再生成可 | Generate 画面へ戻る (`.retried(room)`) | カードがリストから消える |
| 破棄 | `deleteContent(id, type)` | 物理削除、なかったことに | RoomDetail へ戻る (`.discarded`) | カードがリストから消える |
| キャンセル（Result のみ） | なし | 何もせず戻る | RoomDetail へ戻る (`.cancelled`) | — |

> ImageHistory では 3 操作とも結果が同じ（カードが消える）ので、Delegate は `generationDismissed(contentId:)` 1 本に統一する。Result では 3 操作が別の遷移先を持つので Delegate を分離する。

---

## ユーザー回答による要件確定

| 論点 | 決定 |
|---|---|
| 「破棄」のサーバー側挙動 | DELETE で物理削除（`status='failed'` PATCH ではない） |
| 「やり直す」のサーバー側挙動 | `patchStatus(.failed)`（既存 ResultFeature と同じ） |
| `ImageContent.Status` の不整合 | **使われていない `posted` / `discarded` を削除**（`generating` / `pending` の 2 値だけにする） |
| Action の Equatable | `Result<Void, Error>` を使うため **Equatable は外す**（ResultFeature と同方針） |
| 投稿/破棄/やり直し成功後の UX（History） | シートは開いたまま、対象アイテムだけ消える。空になっても自動 dismiss しない |
| 二重タップ防止（History） | **id 単位**。同じカードの3ボタンは進行中だけ disable、別カードは並行操作可 |
| Effect の cancellable | **付けない**（押下後のサーバー反映は完走させる） |
| エラー表示 | History は TCA `AlertState` ＋ `.alert` モディファイア、Result は既存の `errorMessage` 表示 |

---

## api-spec.md との乖離（要追記）

`api-spec.md` には `image_contents` への DELETE エンドポイントが記載されていない（DELETE は `likes` のみ・[api-spec.md:379](../../../api-spec.md#L379)）。Supabase Swift SDK は PostgREST 規約で任意のテーブルに対し `DELETE /rest/v1/image_contents?id=eq.{id}` を発行可能で、`likes` の `unlikeContent` パターン（[ContentRepository.swift:78-90](../../PLAIROOM-iOS/Repository/ContentRepository.swift#L78-L90)）と同じ書き方で実装できる。

実行可否は Supabase 側の RLS ポリシー次第になるため、以下を併せて確認する：

- **要確認**: `image_contents` テーブルの RLS ポリシーが、所有者 (`profile_id = auth.uid()`) による DELETE を許可しているか
- **推奨**: `api-spec.md §4` に「破棄（pending → 削除）」セクションを追記（実装作業とは別タスクで OK）

RLS が DELETE を許可していなければ実機で 403 となるため、実装前に Supabase ダッシュボードで確認する。

---

## 修正対象ファイル

### 1. `Entity/ImageContent.swift`

`Status` enum を **画面上で実際に出現する 2 値に縮小**。

```swift
enum Status: String, Equatable {
    case generating
    case pending
}
```

> 旧 `posted` / `discarded` は **データフロー上到達不能**だった：
> - `OngoingGeneration.asImageContent` は `status: .pending` を固定で返す（[OngoingGeneration.swift:54](../../PLAIROOM-iOS/Entity/OngoingGeneration.swift#L54)）
> - 投稿/破棄/やり直し成功時は `ongoingGenerations` 配列から行ごと削除される（[ContentView.swift:210-214](../../PLAIROOM-iOS/ContentView.swift#L210-L214)）
>
> よって rename ではなく削除。`ImageContent` は API デコードに使われていない（Codable 非準拠）ので、API 仕様との整合は ContentRepository 経由の `ContentStatus`（[ContentItem.swift:9-14](../../PLAIROOM-iOS/Entity/ContentItem.swift#L9-L14)）が単独で担う。

### 2. `Features/ImageHistory/ImageHistoryFeature.swift`

State：

```swift
@ObservableState
struct State: Equatable {
    @Shared(.inMemory("ongoingGenerations")) var ongoingGenerations: IdentifiedArrayOf<OngoingGeneration> = []
    var selectedTab: Tab = .image

    /// 進行中の操作の対象 contentId 集合。
    /// - 同 id の二重タップ抑止に使う（カードの3ボタン全てが disabled）
    /// - 別 id の操作とは並行可能
    var processingIds: Set<String> = []

    @Presents var alert: AlertState<Action.Alert>? = nil

    var items: [ImageContent] { ongoingGenerations.compactMap { $0.asImageContent } }
}
```

Action（**Equatable は付けない**）：

```swift
enum Action: BindableAction {
    case binding(BindingAction<State>)
    case onAppear
    case postTapped(id: String)
    case discardTapped(id: String)
    case retryTapped(id: String)
    case operationResponse(id: String, kind: Operation, Result<Void, Error>)
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    enum Operation: Equatable { case post, discard, retry }
    enum Alert: Equatable {}  // OK ボタンによる dismiss のみ
}

enum Delegate: Equatable {
    case dismissed
    case generationDismissed(contentId: String)
}
```

Reducer ハンドラ要点：

| Action | 主な処理 |
|---|---|
| `postTapped(id)` | `processingIds.contains(id)` なら return `.none`。そうでなければ `processingIds.insert(id)` → `.run { patchStatus(id, .image, .completed) }` → `operationResponse(id, .post, result)` |
| `discardTapped(id)` | 同様に `.run { deleteContent(id, .image) }` |
| `retryTapped(id)` | 同様に `.run { patchStatus(id, .image, .failed) }` |
| `operationResponse(id, _, .success)` | `processingIds.remove(id)` → `.send(.delegate(.generationDismissed(contentId: id)))` |
| `operationResponse(id, kind, .failure(error))` | `processingIds.remove(id)`、`state.alert = AlertState { TextState(title(for: kind)) } message: { TextState(SupabaseError.from(error).localizedDescription) }` |
| `alert(.dismiss)` 等 | 既定（`.ifLet` 任せ） |

エラー文言（操作種別別）：

```swift
private func title(for kind: Operation) -> String {
    switch kind {
    case .post:    "投稿に失敗しました"
    case .discard: "破棄に失敗しました"
    case .retry:   "やり直しに失敗しました"
    }
}
```

`body` に `.ifLet(\.$alert, action: \.alert)` を追加。`@Dependency(\.contentRepository)` は既存。

> **Effect cancel しない**。`postTapped` 等の `.run` には `.cancellable` を付けない。シートが閉じられても通信は完走する（投稿/破棄/失敗扱いはサーバーへコミットすべき確定操作）。store 解放後の `operationResponse` 送信は TCA 側で no-op。

### 3. `Features/ImageHistory/ImageHistoryView.swift`

- `statusBadge` の switch を `generating` / `pending` の **2 ケース**に縮小（旧 posted/discarded ケースは削除）
- カードを **3 ボタン構成**に変更：
  - 上段：`Button("投稿する")`（`.borderedProminent`、横幅いっぱい）
  - 下段 HStack：`Button("やり直す")`（`.bordered`）／`Button("破棄", role: .destructive)`（`.bordered`）
- 進行中表示：そのカードに対応する `processingIds` ヒット時、**3 ボタンとも `disabled(true)`**、かつ「投稿する」ボタン内に `ProgressView()` を表示（ResultView の overlay と異なり、カード単位なのでオーバーレイは出さない）
- 別 id の操作は disable しない（並行可）
- `body` に `.alert($store.scope(state: \.alert, action: \.alert))` を追加

```swift
ForEach(store.items) { item in
    ImageHistoryCard(
        item: item,
        isProcessing: store.processingIds.contains(item.id),
        onPostTapped: { store.send(.postTapped(id: item.id)) },
        onDiscardTapped: { store.send(.discardTapped(id: item.id)) },
        onRetryTapped: { store.send(.retryTapped(id: item.id)) }
    )
}
```

### 4. `Repository/ContentRepository.swift`

DELETE 用メソッドを追加。

```swift
struct ContentRepository: Sendable {
    // ...既存...
    /// 生成コンテンツの物理削除（ユーザーによる「破棄」用）
    var deleteContent: @Sendable (_ contentId: String, _ contentType: ContentType) async throws -> Void
}
```

`liveValue` 実装（`unlikeContent` を雛形）：

```swift
deleteContent: { contentId, contentType in
    @Dependency(\.supabaseClient) var client: SupabaseClient
    try await client
        .from(contentType.tableName)
        .delete()
        .eq("id", value: contentId)
        .execute()
}
```

`testValue` にも `deleteContent: unimplemented()` を追加。

### 5. `Features/Result/ResultFeature.swift`

「破棄」アクションを追加。

```swift
enum Action {
    case onAppear
    case postButtonTapped
    case retryButtonTapped
    case discardButtonTapped     // 新規
    case cancelButtonTapped
    case patchResponse(Result<Void, Error>, action: PostAction)
    case discardResponse(Result<Void, Error>)   // 新規
    case delegate(Delegate)

    enum Delegate {
        case posted
        case cancelled
        case retried(room: Room)
        case discarded            // 新規
    }

    enum PostAction { case post, retry }
}
```

Reducer 追加部分：

```swift
case .discardButtonTapped:
    state.isRequesting = true
    state.errorMessage = nil
    let contentId = state.contentId
    let contentType = state.room.contentType
    return .run { send in
        await send(.discardResponse(
            Result { try await contentRepository.deleteContent(contentId, contentType) }
        ))
    }

case .discardResponse(.success):
    state.isRequesting = false
    return .send(.delegate(.discarded))

case .discardResponse(.failure(let error)):
    state.isRequesting = false
    state.errorMessage = SupabaseError.from(error).localizedDescription
    return .none
```

state-transition.md コメント（ファイル冒頭）にも `discardButtonTapped` 行を追記：

```
//   idle → [*]            : 破棄 → delegate(.discarded)（DELETE）
```

> ResultFeature は単一コンテンツに対する操作なので、State は既存の `isRequesting: Bool` のままで十分（History のような Set は不要）。

### 6. `Features/Result/ResultView.swift`

`actionButtons` に「破棄」ボタンを追加。

```swift
private var actionButtons: some View {
    VStack(spacing: 12) {
        Button { store.send(.postButtonTapped) } label: {
            Text("投稿する").fontWeight(.semibold).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(store.isRequesting)

        Button { store.send(.retryButtonTapped) } label: {
            Text("やり直す").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(store.isRequesting)

        Button(role: .destructive) { store.send(.discardButtonTapped) } label: {
            Text("破棄").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(store.isRequesting)
    }
}
```

> 既存のローディングオーバーレイ（`ZStack` 配下の "処理中..." ProgressView）はそのまま機能する。

### 7. 親 View での Delegate 受信

- `ImageHistoryFeature.Delegate.generationDismissed(contentId)` の受信側は既存（[ContentView.swift:225-234](../../PLAIROOM-iOS/ContentView.swift#L225-L234)）。3 操作いずれも同じ Delegate を流すため**変更不要**。
- `ResultFeature.Delegate.discarded` は現時点で親 Feature に未統合（`grep` で参照なし）。実装時に親側へ統合する場合は **`.posted` と同じ遷移（RoomDetail へ戻る）** とすること。

---

## Effect の生存期間（明文化）

`postTapped` / `discardTapped` / `retryTapped` の `.run` Effect には `.cancellable(id:)` を **付けない**。

- ボタン押下＝サーバーへのコミット指示として確定する
- シートを閉じても、別画面に遷移しても、書き込み（PATCH/DELETE）は完走させる
- Effect 完了前に store が破棄された場合、`operationResponse` 送信は TCA 内で no-op になり実害なし
- これは「書き込みは確定、表示の片付けは独立」というポリシーの明示

---

## 検証手順

1. `xcodebuild -project PLAIROOM-iOS.xcodeproj -scheme PLAIROOM-iOS -configuration Debug build` でビルドが通ることを確認
2. iPhone シミュレータで起動 → ログイン → ルームに入って画像を生成
3. 生成完了 → MiniPlayer タップ → ImageHistory シート表示
4. **投稿シナリオ（History）**：「投稿する」タップ
   - ボタンに ProgressView が出てから消える
   - 同カードの「破棄」「やり直す」も同時に disable されること
   - **別カードのボタンは押せること（並行操作）**
   - アイテムがリストから消える
   - Supabase ダッシュボードで `image_contents` の該当行が `status='completed'` になっていること
5. **やり直しシナリオ（History）**：別の生成 → 「やり直す」タップ
   - アイテムがリストから消える
   - 該当行の `status='failed'` になっていること（行は残る）
6. **破棄シナリオ（History）**：別の生成 → 「破棄」タップ
   - アイテムがリストから消える
   - 該当行が**削除されている**こと（RLS で 403 になる場合はポリシー対応が必要）
7. **空状態（History）**：全アイテムを処理して 0 件 → "生成中のコンテンツはありません" の empty view が表示され、**シートは開いたまま**であること
8. **エラーシナリオ（History）**：機内モード ON で「投稿する」タップ
   - アラートに「投稿に失敗しました」＋ ネットワーク文言
   - OK で alert が閉じ、`processingIds` が解除されてボタンが再度押せること
9. **破棄シナリオ（Result）**：生成完了 → 結果画面 → 「破棄」タップ
   - 処理中オーバーレイが出る
   - DELETE 完走後、RoomDetail へ戻ること
10. **やり直しシナリオ（Result）**：従来通り Generate 画面に戻ること（回帰確認）
11. **シート閉鎖中の in-flight**：「投稿する」を押した直後にシートを下スワイプで閉じる → サーバー側ステータスが `completed` になっていること（書き込み完走の確認）
