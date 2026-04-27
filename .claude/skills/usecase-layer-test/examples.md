# 例

## 例1: create 系 Reducer `GenerateFeature`

前提:

- `GenerateFeature` はユーザーがプロンプトを入力して画像/音楽を生成する Reducer
- `tappedGenerate` Action を起点に、認可確認 → API 呼び出し → 結果保存 → 完了通知の順で進む
- `@Dependency(\.contentRepository)` と `@Dependency(\.authClient)` が注入される
- 成功時は `delegate(.didGenerate(Content))` を発行する

項目表:

| No | 観点 | 事前状態/入力 | 実行 | 期待結果 | 備考 |
|---|---|---|---|---|---|
| 1 | `正常系` | ログイン済み、prompt 入力済み | `.tappedGenerate` 送信 | `isLoading` true → API 呼び出し → State に結果反映 → `delegate(.didGenerate)` 発行 | 基本ケース |
| 2 | `認可` | 未ログイン | `.tappedGenerate` 送信 | 早期失敗、`alert` 表示、API 呼び出されない | 認可エラー |
| 3 | `入力解釈` | prompt が空 | `.tappedGenerate` 送信 | エラー State、API 呼び出されない | バリデーション |
| 4 | `Entity 呼び出し` | 正常入力 | `.tappedGenerate` 送信 | `Content` Entity が生成され State に反映される | Entity は本物を使う |
| 5 | `Repository / API client 呼び分け` | 画像モード / 音楽モード | `.tappedGenerate` 送信 | モードに応じて正しい Repository メソッドを呼ぶ | 条件分岐 |
| 6 | `Effect 発行順序` | 正常入力 | `.tappedGenerate` 送信 | API 呼び出し成功後に `delegate` を発行する | 順序確認 |
| 7 | `Effect 未発行` | API 呼び出し失敗 | `.tappedGenerate` 送信 | `delegate(.didGenerate)` は発行されない | 後続停止 |
| 8 | `外部依存失敗` | Supabase API 失敗 | `.tappedGenerate` 送信 | `isLoading` false、`alert` に エラー反映 | エラー表示 |
| 9 | `State 出力` | 生成成功 | `.tappedGenerate` 送信 | `state.result` に必要項目だけ詰まる | View が表示する形 |
| 10 | `delegate Action / 親への通知` | 生成成功 | `.tappedGenerate` 送信 | 親 Reducer 向けに `delegate(.didGenerate(content))` を 1 回発行 | navigation トリガ |
| 11 | `エラー伝播` | `ContentError.quotaExceeded` 発生 | `.tappedGenerate` 送信 | エラー型を保ったまま State に反映する | HTTP status 変換はしない |
| 12 | `回帰` | 過去に二重発火していた連打条件 | `.tappedGenerate` を高速連打 | 二重発火しない (`Effect.cancellable` で防御) | 再発防止 |

補足:

- 時間に依存する Effect (debounce 等) があれば `TestClock` を使う前提を備考に書く
- この例では query 系や background task の観点は省略している

## 例2: background task 系 Reducer `RoomListFeature` のリフレッシュ

前提:

- `RoomListFeature` は画面表示時とプル to リフレッシュ時に Room 一覧を取得する
- 非同期 Effect でロードし、cancellation を考慮する
- 重複リクエストは `Effect.cancellable(id:)` で打ち消す

項目表:

| No | 観点 | 事前状態/入力 | 実行 | 期待結果 | 備考 |
|---|---|---|---|---|---|
| 1 | `正常系` | 認可 OK、Room データあり | `.onAppear` 送信 | `isLoading` true → `roomsResponse(.success)` 受信 → `state.rooms` に反映 | 基本ケース |
| 2 | `入力解釈` | 検索キーワードあり | `.search(query:)` 送信 | 必要なクエリパラメータが Repository に渡る | 引数確認 |
| 3 | `Entity 呼び出し` | レスポンス成功 | `.onAppear` 送信 | DTO → `Room` Entity へ変換され State に入る | mapping 確認 |
| 4 | `Repository / API client 呼び分け` | 全件 / 自分の Room のみ | `.onAppear` 送信 | フィルタに応じて正しい Repository メソッドを呼ぶ | 取得条件確認 |
| 5 | `Effect 発行順序` | 連続で `.onAppear` 送信 | 高速連打 | 古い Effect が cancel され、最新のみ State に反映 | cancellable id で防御 |
| 6 | `Effect 未発行` | 取得失敗 | `.onAppear` 送信 | 後続の navigation Effect が発行されない | 後続停止 |
| 7 | `外部依存失敗` | Supabase 一時失敗 | `.onAppear` 送信 | `state.error` にエラー反映、`isLoading` false に戻る | retry は仕様次第 |
| 8 | `回帰` | 過去に発生した状態リーク | 画面遷移 → 戻る → `.onAppear` | 古い rooms が残らない | 再発防止 |

補足:

- 非同期 Reducer では cancellation、冪等性、再実行条件を `Effect 発行順序` や `回帰` の補助観点として備考へ出してよい
- この例では `認可` と `delegate Action` を省略している。仕様に応じて追加する
