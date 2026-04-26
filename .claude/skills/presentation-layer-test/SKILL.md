---
name: presentation-layer-test
description: This skill should be used for SwiftUI View / ViewState mapping / 表示用書式変換 / accessibility / snapshot / view layer tests, ビュー層テスト, プレゼンテーション層テスト, and テスト項目表 in this Swift/SwiftUI/TCA iOS app. It organizes view test viewpoints, creates a unit/snapshot/UI-aware test case matrix from user requirements and relevant code or specs, revises the matrix based on feedback, and generates Swift Testing code only after explicit approval.
---

# View (SwiftUI) 層テスト

## いつ使うか

- `Features/<FeatureName>/<...>View.swift` のテストを新規作成したいとき
- SwiftUI View、ViewState mapping、表示用書式変換、accessibility のテスト観点を整理したいとき
- 先に「View テストで何を見るべきか」を決めてから項目表へ落としたいとき
- `unit (ロジック単体)` と `snapshot / UI integration` の境界を明示してからテスト設計したいとき
- 項目表をユーザーと合意してから Swift Testing のテストコードへ落としたいとき

## このスキルの対象

- このリポジトリの **TCA における SwiftUI View 層テスト**
- `Features/<FeatureName>/<...>View.swift` および View 補助コンポーネント
- `ViewState` / `ViewStore` 経由の State から View 表示への mapping
- 表示用書式変換 (日付、価格、ラベル) を行う formatter
- View 単位の accessibility (label, hint, traits)
- スナップショットテスト用の決定的レンダリング
- HTTP 入口ではなく、ユーザー操作 (タップ / スワイプ / フォーカス) を Action へ変換する境界

このスキルは、Reducer 本体の State 遷移や Effect 検証は主対象にしない。
それらが主題なら `usecase-layer-test` (Feature/Reducer) の判断を優先する。
Entity の不変条件本体は `domain-layer-test` を優先する。

## 期待する出力

- 第 1 段階では、**観点整理** を返す
- 第 2 段階では、`unit` / `snapshot or UI integration` を分けた **テスト項目表** を返す
- 第 3 段階では、ユーザー指摘を反映した **修正版の項目表** を返す
- 第 4 段階では、承認済み項目表に沿った **Swift Testing のテストコード** を作成する
- 各段階で、**対象、観点、前提、テスト種別、期待結果、境界の判断** を短く明示する

## 基本原則

- **先に観点整理、次に表、最後にコード**
- **View テストは Entity / Reducer の責務と混ぜない**
- **`unit (ロジック単体)` と `snapshot / UI integration` の境界を先に明示する**
- **ViewState mapping、表示用書式変換、ユーザー操作 → Action 変換、accessibility を重視する**
- **SwiftUI 固有 API は View に閉じ込め、その境界をテストで確認する**
- **Reducer ルール本体の再検証はしない**
- **スナップショットや UI test に頼る前に、まず ViewState / formatter を pure に切り出して unit test できないか検討する**
- **ユーザーの明示承認があるまで、テストコードは作らない**

## 最初に確認する

1. ユーザーが求めているのは **観点整理** か **項目表** か **コード生成** か
2. 対象は SwiftUI View 全体、特定の subview、ViewState 派生 property、formatter のどれか
3. これは `unit (ロジック単体)` で閉じる話か、`snapshot` または UI test が必要か
4. 何を隔離したいのか: Reducer (`Store`)、formatter、Locale、Color/Asset、画像読み込み
5. ViewState mapping、表示用書式変換、accessibility、ユーザー操作 → Action 変換のどれが主題か
6. 既存実装や既存テストに `TestStore` 連携、`StateOf`、Preview の流儀があるか
7. snapshot を使う場合、ライブラリ (例: `swift-snapshot-testing`) や決定的レンダリングの前提は揃っているか

必要情報が不足する場合は、推測で埋め切らず、前提を明示して確認する。

## 作業の入口

### 1. 観点を整理する

- まず親プロジェクトの `CLAUDE.md`、`./CLAUDE.md`、`./ARCHITECTURE.md` を確認する
- 必要に応じて `swiftui-pro`、`swift-testing-pro`、`anthropic-skills:tca`、`swift-api-design-guidelines-skill` skill を確認する
- ユーザー入力、添付ファイル、親プロジェクトの `.md` 仕様、対象 View / Reducer から材料を集める
- 次の観点セットを基準に、必要な観点だけを選ぶ

1. ViewState mapping
2. 表示用書式変換
3. 表示分岐 / 条件レンダリング
4. ユーザー操作 → Action 変換
5. navigation / sheet / alert 表示
6. error 表示
7. loading / empty / error の状態表現
8. accessibility
9. localization
10. layout / snapshot
11. SwiftUI 依存の隔離
12. 仕様整合 (デザイン仕様 / `../requirements.md` 等)
13. 回帰

### 2. 項目表を作る

- `unit (ロジック単体)` と `snapshot / UI integration` を分けて表へ落とす
- View 全体、subview、formatter を同じ観点で無理に埋めない
- 対象に不要な観点は省略してよい
- 省略した観点があれば補足へ短く書く

### 3. 項目表を修正する

- ユーザー指摘を受けたら、行を追加、削除、統合、分割する
- 修正時は「何を変えたか」を短く添える

### 4. テストコードを作る

- 承認済み項目表を source of truth として扱う
- `unit` は ViewState / formatter / pure 関数だけを切り出して Swift Testing で確認する
- `snapshot / UI integration` はスナップショット (例: `swift-snapshot-testing`) や `XCUIApplication` を通して確認する
- snapshot を使う場合、Locale / Dynamic Type / ダークモード / デバイス設定の前提を結果に明記する
- Reducer の State 遷移検証が主題なら、コード化前に `usecase-layer-test` 側で扱う旨を先に報告する
- Entity の業務ルール本体が混ざる場合も、コード化前に先に報告する

### 承認の判定

- 次段階へ進む条件は、**直前に提示した項目表に対する明示承認** があること
- 明示承認の例: `OK`, `いいよ`, `進めて`, `LGTM`, `これでテストコードを書いて`, `表はこれでよい`
- 表を修正したあとは、**修正版に対して改めて承認** を取る
- いきなりコード作成を求められても、直前の項目表が未承認なら、項目表を再提示または要約して確認する
- 承認が曖昧なら、コード化へ進まず 1 文で確認する

## 項目表の作り方

### 推奨カラム

次の列を基本形とする。

| No | テスト種別 | 対象 | 観点 | 事前状態/入力 | 実行 | 期待結果 | 備考 |
|---|---|---|---|---|---|---|---|
| 1 | `unit` |  |  |  |  |  |  |

### 観点の使い分け

- View 全体 (例: `RoomListView`):
  - `ViewState mapping`
  - `表示分岐 / 条件レンダリング`
  - `ユーザー操作 → Action 変換`
  - `navigation / sheet / alert 表示`
  - `loading / empty / error の状態表現`
  - `accessibility`
  - `layout / snapshot`
  - `SwiftUI 依存の隔離`
  - `仕様整合`
  - `回帰`
- ViewState / 派生 property:
  - `ViewState mapping`
  - `表示分岐 / 条件レンダリング`
  - `仕様整合`
  - `回帰`
- formatter / 表示用変換:
  - `表示用書式変換`
  - `localization`
  - `仕様整合`
  - `回帰`
- subview / 共通コンポーネント:
  - `ViewState mapping`
  - `accessibility`
  - `layout / snapshot`
  - `回帰`

### 表の出し方

- 先に 1 行で対象と前提を書く
- その下に Markdown 表を置く
- 表の行は、基本として **`unit` を先、`snapshot / UI integration` を後** にする
- 同じテスト種別の中では、**観点の分類順を優先** して並べる
- 表の下に、今回使った観点の意味を 1 行ずつ短く補足してよい
- 観点が強く重なる行は、無理に分けず統合してよい
- 表の後に、**Entity / Feature / View の境界で除外した項目** があれば短く書く

### 観点の短い説明

- `ViewState mapping`: Reducer の State から View 表示用の値 (タイトル、有効/無効、件数) へ正しく変換できること
- `表示用書式変換`: 日付、価格、ラベルなどの見せ方を View 側で正しく整えること
- `表示分岐 / 条件レンダリング`: State に応じて出すべきコンポーネントだけを描画すること
- `ユーザー操作 → Action 変換`: タップ、スワイプ、フォーカス変更が正しい Action として Reducer に届くこと
- `navigation / sheet / alert 表示`: TCA の `@Presents` / `Path` を介した遷移が State と整合すること
- `error 表示`: error State を View 上で正しく見せること
- `loading / empty / error の状態表現`: 各状態でユーザーに見える要素が想定どおりであること
- `accessibility`: VoiceOver ラベル、Dynamic Type、Hit target などが妥当であること
- `localization`: 日本語 / 英語などのロケール差で文言が壊れないこと
- `layout / snapshot`: 主要な画面サイズやテーマでレイアウトが崩れないこと
- `SwiftUI 依存の隔離`: SwiftUI 固有 API や `View` 型が Reducer / Entity 側へ漏れていないこと
- `仕様整合`: 親プロジェクトの仕様文書 (`../requirements.md` 等) や UI 仕様と表示が矛盾しないこと
- `回帰`: 過去のレイアウト崩れ、文言ミス、navigation 不具合が再発しないこと

## コード生成のルール

- 先に表との対応関係を確認する
- `unit` と `snapshot / UI integration` を同じファイルへ雑に混ぜない
- snapshot を使う場合、テスト用のデバイス、Locale、Dynamic Type、ダークモードの組合せを限定し、前提を明記する
- TCA の View ロジック検証は、可能な限り pure な ViewState / formatter に切り出して `Swift Testing` で書く
- Entity ルール本体や Reducer の調停を View test で再検証しすぎない
- スナップショットの差分が出た場合は、原因を切り分けてから baseline を更新する

## してはいけないこと

- いきなりテストコードを書き始めること
- `unit` と `snapshot / UI integration` の境界を曖昧なまま項目表を作ること
- View で表示できているからといって Reducer / Entity のテストを省略すること
- Reducer の Effect や Repository 呼び出しを View test で再検証すること
- SwiftUI 固有型 (`AnyView`, `Binding`) を Reducer や Entity へ持ち込む前提でテストを書くこと
- スナップショット差分を中身を見ずに baseline 上書きで通すこと
- user approval 前に「表は仮でいいから」とコード化へ進むこと

## 回答テンプレート

### 観点整理を返すとき

1. **対象**: 何の View 層テストか
2. **前提**: どの情報を根拠にしたか
3. **観点整理**: 今回採用する観点一覧
4. **補足**: `unit` / `snapshot or UI integration` の切り分け、除外した責務

### 項目表を返すとき

1. **対象**: 何のテスト項目表か
2. **前提**: どの情報を根拠にしたか
3. **項目表**: Markdown 表
4. **観点の説明**: 今回使った観点の意味を短く補足
5. **補足**: 除外した責務、未確定事項、確認したい点

### 修正版を返すとき

1. **変更点**: 何を追加、削除、修正したか
2. **修正版の項目表**
3. **観点の説明**: 必要なら更新後の観点を短く補足
4. **確認事項**: 必要なら 1 つか 2 つ

### コード生成に進むとき

1. 承認済み項目表との対応を短く示す
2. `unit` と `snapshot / UI integration` をどのファイルへ作るか示す (`PLAIROOM-iOSTests/Features/...`、`PLAIROOM-iOSUITests/...`)
3. 実装後に、表の各観点をどこまでカバーしたかを短く報告する

## 追加資料

- SwiftUI View 設計レビュー: `swiftui-pro` skill
- TCA における View / Store の扱い: `anthropic-skills:tca` skill
- Swift Testing の書き方: `swift-testing-pro` skill
- 例: [examples.md](examples.md)
