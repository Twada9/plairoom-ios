# 例

## 例1: View `RoomListView`

前提:

- `RoomListView` は `RoomListFeature` の `Store` を受け取り、`rooms` を一覧表示する
- 空状態 (`rooms.isEmpty && !isLoading`) では空表示メッセージを出す
- ロード中 (`isLoading`) では `ProgressView` を表示する
- セルタップで `.tappedRoom(Room)` Action を Reducer に送る
- 表示用に `Room.lastUpdatedAt` を「YYYY/MM/dd HH:mm」へ整形する

項目表:

| No | テスト種別 | 対象 | 観点 | 事前状態/入力 | 実行 | 期待結果 | 備考 |
|---|---|---|---|---|---|---|---|
| 1 | `unit` | `RoomListView.ViewState` | `ViewState mapping` | `state.rooms = [...]` | ViewState 派生 | タイトル、件数表示が想定どおり | 基本ケース |
| 2 | `unit` | `RoomListView.ViewState` | `表示分岐 / 条件レンダリング` | `rooms.isEmpty && !isLoading` | ViewState 派生 | 空表示フラグが true | empty 状態 |
| 3 | `unit` | `RoomListView.ViewState` | `loading / empty / error の状態表現` | `isLoading == true` | ViewState 派生 | loading フラグ true、本体は描画しない | loading 状態 |
| 4 | `unit` | 日付 formatter | `表示用書式変換` | `Date(timeIntervalSince1970: ...)` | formatter 適用 | `2026/04/27 10:00` 形式の文字列 | Locale 固定 |
| 5 | `unit` | 日付 formatter | `localization` | Locale を `en_US` に変更 | formatter 適用 | 日付フォーマットが英語ロケールで壊れない | 多言語対応 |
| 6 | `unit` | `RoomListView` | `ユーザー操作 → Action 変換` | `Store` を `TestStore` で渡し、セルを tap する想定 | tap | `.tappedRoom(room)` が送信される | TCA との結線確認 |
| 7 | `snapshot or UI integration` | `RoomListView` | `layout / snapshot` | `rooms` 3 件、ライトモード | snapshot 撮影 | 既存 baseline と一致 | iPhone 標準サイズ |
| 8 | `snapshot or UI integration` | `RoomListView` | `loading / empty / error の状態表現` | `isLoading == true` | snapshot 撮影 | `ProgressView` だけが見える状態 | loading snapshot |
| 9 | `snapshot or UI integration` | `RoomListView` | `accessibility` | VoiceOver で順に読み上げ | UI test | 各セルの label が読まれる、ボタン traits が付く | VoiceOver 確認 |
| 10 | `snapshot or UI integration` | `RoomListView` | `回帰` | 過去にレイアウト崩れた長いタイトル | snapshot 撮影 | 折り返しが想定どおりで崩れない | 再発防止 |

補足:

- この例では `navigation / sheet / alert 表示` を省略している。詳細画面遷移を扱うなら `RoomListFeature.path` を含めて追加する
- `ViewState mapping` を pure に切り出してテストすれば、UI test の負担を減らせる
- snapshot を採用する場合、Locale / Dynamic Type / ダークモードの組合せは限定し、前提を明記する

## 例2: 共通コンポーネント `LoadingFooterView`

前提:

- `LoadingFooterView` はリスト末尾に追加読み込み中表示を出す
- `state == .loading / .reachedEnd / .error(message)` の `enum` を受け取って描画を切り替える
- ボタン押下で再試行 closure を呼ぶ

項目表:

| No | テスト種別 | 対象 | 観点 | 事前状態/入力 | 実行 | 期待結果 | 備考 |
|---|---|---|---|---|---|---|---|
| 1 | `unit` | `LoadingFooterView.ViewState` | `ViewState mapping` | `.loading` | ViewState 派生 | spinner 表示、本文非表示 | 基本ケース |
| 2 | `unit` | `LoadingFooterView.ViewState` | `表示分岐 / 条件レンダリング` | `.reachedEnd` | ViewState 派生 | 「以上です」表示、再試行ボタン非表示 | 表示分岐 |
| 3 | `unit` | `LoadingFooterView.ViewState` | `error 表示` | `.error("失敗しました")` | ViewState 派生 | error メッセージと再試行ボタン表示 | error 状態 |
| 4 | `unit` | `LoadingFooterView` | `ユーザー操作 → Action 変換` | `.error(...)` | 再試行ボタン tap | 再試行 closure が 1 回呼ばれる | コールバック確認 |
| 5 | `snapshot or UI integration` | `LoadingFooterView` | `accessibility` | `.loading` | accessibility audit | spinner が「読み込み中」と読み上げられる | VoiceOver 確認 |
| 6 | `snapshot or UI integration` | `LoadingFooterView` | `layout / snapshot` | 各 state | snapshot 撮影 | baseline と一致 | 状態ごとのレイアウト確認 |

補足:

- この例では `localization` と `仕様整合` を省略している。文言が確定したら追加する
- 共通コンポーネントは ViewState を切り出して `unit` 中心に検証し、snapshot は最低限に絞る
