---
name: usecase-layer-test
description: This skill should be used for `Features/` (TCA Reducers), Action handling, Effect ordering, State transitions, dependency injection, output/return values, Reducer tests, フィーチャー層テスト, Reducer テスト, ユースケース層テスト, and テスト項目表 in this Swift/SwiftUI/TCA iOS app. It organizes Reducer test viewpoints, creates a table-first test case matrix from user requirements and relevant code or specs, revises the matrix based on feedback, and generates Swift Testing code only after explicit approval.
---

# Feature (TCA Reducer) 層テスト

## いつ使うか

- `Features/` 配下の TCA Reducer のテストを新規作成したいとき
- Reducer のテスト観点を整理したいとき
- 先に「Reducer テストで何を見るべきか」を決めてから項目表へ落としたいとき
- 認可、Effect 発行、副作用順序、失敗時の扱いを含めてテスト設計したいとき
- 項目表をユーザーと合意してから Swift Testing のテストコードへ落としたいとき

## このスキルの対象

- このリポジトリの **TCA における Feature (Reducer) 層テスト**
- `Features/` 配下に置く Swift Testing のテスト
- `@Reducer` で定義された Feature の State / Action / body / Effect
- `@Dependency` で注入される Repository、API client、clock、uuid 等の差し替え
- 親プロジェクトの仕様 (`../requirements.md`、`../state-transition.md`、`../api-spec.md`) を根拠にしたユースケース流れの確認

このスキルは、Entity 単体の不変条件や値検証本体は主対象にしない。
それらが主題なら `domain-layer-test` (Entity) の判断を優先する。
SwiftUI View の表示や ViewState mapping が主題なら `presentation-layer-test` (View) を優先する。

## 期待する出力

- 第 1 段階では、**観点整理** を返す
- 第 2 段階では、**テスト項目表** を返す
- 第 3 段階では、ユーザー指摘を反映した **修正版の項目表** を返す
- 第 4 段階では、承認済み項目表に沿った **Swift Testing のテストコード (`TestStore` ベース)** を作成する
- 各段階で、**対象、観点、前提、期待結果、境界の判断** を短く明示する

## 基本原則

- **先に観点整理、次に表、最後にコード**
- **Reducer テストはユーザー操作から State 遷移、Effect 発行までの流れ全体を検証する**
- **Entity (domain model) はモックしない**
- **`@Dependency` で注入される Repository、API client、clock、uuid などは test value (stub / fake / spy) で分離する**
- **副作用 (Effect) がないことではなく、副作用が正しく制御されていることを確認する**
- **認可、Effect 発行順序、Effect 未発行、戻り値 / 表示用 State、エラー伝播を重視する**
- **Entity の不変条件そのものを Reducer 層で再検証しすぎない**
- **`TestStore` の exhaustive モードを基本にし、不要に non-exhaustive へ逃げない**
- **ユーザーの明示承認があるまで、テストコードは作らない**

## 最初に確認する

1. ユーザーが求めているのは **観点整理** か **項目表** か **コード生成** か
2. 対象は画面 Reducer、子 Reducer、scoped feature、TCA の `@Reducer(state: ...)` 構造のどれか
3. 認可、非同期 Effect、Effect 順序、外部依存失敗のどれが主題か
4. 複数の Repository / API client をまたぐか
5. 戻り値は State 更新だけか、delegate Action や親へのコールバックがあるか
6. 既存実装や既存テストに `TestStore`、`withDependencies`、`@Dependency` の流儀があるか

必要情報が不足する場合は、推測で埋め切らず、前提を明示して確認する。

## 作業の入口

### 1. 観点を整理する

- まず親プロジェクトの `CLAUDE.md`、`./CLAUDE.md`、`./ARCHITECTURE.md`、`./APIINTEGRATION.md` を確認する
- 必要に応じて `anthropic-skills:tca`、`swift-testing-pro`、`swift-concurrency-pro` skill を確認する
- ユーザー入力、添付ファイル、親プロジェクトの `.md` 仕様、対象コードから材料を集める
- `../state-transition.md` があるなら、項目表の前提にどの状態遷移を根拠にしたか短く書く
- 次の観点セットを基準に、必要な観点だけを選ぶ

1. 正常系
2. 認可
3. 入力解釈
4. Entity 呼び出し
5. Repository / API client 呼び分け
6. Effect 発行順序
7. Effect 未発行
8. 外部依存失敗
9. State 出力
10. delegate Action / 親への通知
11. エラー伝播
12. 回帰

非同期 Effect や long running task が主題なら、cancellation、retry、冪等性、再実行条件は
`Effect 発行順序` や `外部依存失敗` や `回帰` の補助観点として備考列や補足へ出してよい。
時間に依存する Effect は `TestClock` などで時間を進めるテスト方針を備考に書く。

### 2. 項目表を作る

- まず観点を整理し、その後に Markdown 表へ落とす
- 対象に不要な観点は省略してよい
- 省略した観点があれば補足へ短く書く
- Entity ルール本体まで Reducer の項目表に入れない

### 3. 項目表を修正する

- ユーザー指摘を受けたら、行を追加、削除、統合、分割する
- 修正時は「何を変えたか」を短く添える

### 4. テストコードを作る

- 承認済み項目表を source of truth として扱う
- Entity (domain model) は本物を使う
- Repository、API client、`Clock`、`UUIDGenerator`、Notifier 等は `withDependencies` で stub / fake / spy に差し替える
- `TestStore` で State 遷移と Action 受信を検証する
- 呼び回数の細かい確認より、結果と Effect 発行条件を優先する
- Entity や Repository の責務が混ざる場合は、コード化前に先に報告する

### 承認の判定

- 次段階へ進む条件は、**直前に提示した項目表に対する明示承認** があること
- 明示承認の例: `OK`, `いいよ`, `進めて`, `LGTM`, `これでテストコードを書いて`, `表はこれでよい`
- 表を修正したあとは、**修正版に対して改めて承認** を取る
- いきなりコード作成を求められても、直前の項目表が未承認なら、項目表を再提示または要約して確認する
- 承認が曖昧なら、コード化へ進まず 1 文で確認する

## 項目表の作り方

### 推奨カラム

次の列を基本形とする。

| No | 観点 | 事前状態/入力 | 実行 | 期待結果 | 備考 |
|---|---|---|---|---|---|
| 1 |  |  |  |  |  |

### 観点の使い分け

- create / register 系 Reducer (例: `GenerateFeature`):
  - `正常系`
  - `認可`
  - `入力解釈`
  - `Entity 呼び出し`
  - `Repository / API client 呼び分け`
  - `Effect 発行順序`
  - `Effect 未発行`
  - `外部依存失敗`
  - `State 出力`
  - `delegate Action / 親への通知`
  - `エラー伝播`
  - `回帰`
- update / state-change 系 Reducer (例: `RoomDetailFeature` の状態変更):
  - `正常系`
  - `認可`
  - `Entity 呼び出し`
  - `Repository / API client 呼び分け`
  - `Effect 発行順序`
  - `Effect 未発行`
  - `エラー伝播`
  - `回帰`
- query / list 系 Reducer (例: `RoomListFeature`):
  - `正常系`
  - `認可`
  - `入力解釈`
  - `Repository / API client 呼び分け`
  - `State 出力`
  - `エラー伝播`
  - `回帰`
- background task / long running 系 Reducer:
  - `正常系`
  - `認可`
  - `入力解釈`
  - `Entity 呼び出し`
  - `Repository / API client 呼び分け`
  - `Effect 発行順序`
  - `Effect 未発行`
  - `外部依存失敗`
  - `エラー伝播`
  - `回帰`

### 表の出し方

- 先に 1 行で対象と前提を書く
- その下に Markdown 表を置く
- 表の行は、基本として **観点の分類順を優先** して並べる
- 表の下に、今回使った観点の意味を 1 行ずつ短く補足してよい
- 観点が強く重なる行は、無理に分けず統合してよい
- 表の後に、**Entity / Feature / Repository の境界で除外した項目** があれば短く書く

### 観点の短い説明

- `正常系`: ユーザー操作からの一連の Action と Effect が期待どおり最後まで進むこと
- `認可`: 実行権限のないユーザーやセッションを適切に拒否すること
- `入力解釈`: Action のペイロードや State から必要情報を正しく扱うこと
- `Entity 呼び出し`: 必要な Entity の生成・更新が行われること
- `Repository / API client 呼び分け`: 条件に応じて正しい `@Dependency` 注入先を使うこと
- `Effect 発行順序`: 保存、通知、navigation などの Effect が正しい順序で発行されること
- `Effect 未発行`: 前段で失敗したとき、後続 Effect が走らないこと
- `外部依存失敗`: Repository / API client の失敗時挙動 (State、リトライ、エラー表示) が仕様どおりであること
- `State 出力`: 最終的な State が外部から見て適切な形であること
- `delegate Action / 親への通知`: 親 Reducer や別 feature への通知が必要なときに正しく発行されること
- `エラー伝播`: 上位へエラーを返す経路 (`State.error`、`alert`、delegate Action) が壊れていないこと
- `回帰`: 過去の不具合や仕様誤解が再発しないこと

## コード生成のルール

- 先に表との対応関係を確認する
- Entity (domain model) はモックしない
- Repository、API client、Clock、UUIDGenerator は `withDependencies { $0.xxx = ... }` でスタブ化、または fake / spy に差し替える
- 呼び順や呼び回数の確認は、`TestStore` の Action 受信検証で必要なものだけに絞る
- View 向けの表示書式変換は Reducer test に持ち込まない (presentation 側で扱う)
- 途中失敗時の Effect 未発行や cancellation は優先して確認する
- 非同期 Effect は `TestStore.send`、`TestStore.receive`、`TestClock.advance` を組み合わせる

## してはいけないこと

- いきなりテストコードを書き始めること
- Entity (domain model) までモック化すること
- Reducer 層で単一 Entity の不変条件を再検証しすぎること
- Effect 発行順序や失敗時方針を曖昧なまま項目表を作ること
- SwiftUI 表示書式や色の都合を Reducer の責務として扱うこと
- `TestStore` を non-exhaustive モードで安易に使い、Effect 漏れを隠すこと
- user approval 前に「表は仮でいいから」とコード化へ進むこと

## 回答テンプレート

### 観点整理を返すとき

1. **対象**: 何の Reducer 層テストか
2. **前提**: どの情報を根拠にしたか (親プロジェクトの仕様、対象 Reducer、既存テスト)
3. **観点整理**: 今回採用する観点一覧
4. **補足**: 除外した責務、未確定事項

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
2. どのファイルへ何のテストを作るか示す (`PLAIROOM-iOSTests/Features/<FeatureName>/...`)
3. 実装後に、表の各観点をどこまでカバーしたかを短く報告する

## 追加資料

- TCA Reducer / TestStore の書き方: `anthropic-skills:tca` skill
- Swift Testing の書き方: `swift-testing-pro` skill
- async / Effect の検証: `swift-concurrency-pro` skill
- 例: [examples.md](examples.md)
