---
name: domain-layer-test
description: This skill should be used when designing, refining, reviewing, or implementing Entity (domain model) layer tests for this Swift/SwiftUI/TCA iOS app. It creates a table-first test case matrix from user requirements and parent specs (`../requirements.md`, `../technical-design.md`, `../state-transition.md`), revises the matrix based on feedback, and only generates Swift Testing code after explicit approval. Use when the user mentions `Entity/`, domain model, value types, struct/enum, decoding, validation, ドメイン層テスト, エンティティ層テスト, テスト項目表, or 承認後にテストコード化.
---

# Entity (ドメインモデル) 層テスト

## いつ使うか

- `Entity/` 配下のテストを新規作成したいとき
- Entity (ドメインモデル) のテスト項目表を、ユーザー入力と親プロジェクトの `.md` 仕様 (`../requirements.md`、`../technical-design.md`、`../state-transition.md`) から起こしたいとき
- value type (`struct` / `enum`)、ドメインの不変条件、状態遷移、デコードのテスト観点を整理したいとき
- 「どこまでが Entity test で、どこからが Feature (Reducer) test か」を切り分けたいとき
- 先にテスト項目表を合意してから、Swift Testing のテストコードへ落としたいとき

## このスキルの対象

- このリポジトリの **TCA における Entity (ドメインモデル) 層テスト**
- `Entity/` 配下に置く Swift Testing のテスト
- `Room`、`ImageContent`、`MusicContent`、`Like`、`Comment` などの Entity
- 親プロジェクトの仕様文書 (`../requirements.md`、`../technical-design.md`、`../state-transition.md`)

このスキルは、Repository / API client の通信テスト、SwiftUI View のスナップショット、Reducer の State 遷移テストを主対象にしない。
それらが主題なら `usecase-layer-test` (Feature/Reducer) や `presentation-layer-test` (View) の判断を優先する。

## 期待する出力

- 第 1 段階では、**テスト項目表** を返す
- 第 2 段階では、ユーザー指摘を反映した **修正版の項目表** を返す
- 第 3 段階では、承認済み項目表に沿った **Swift Testing のテストコード** を作成する
- 各段階で、**対象、観点、前提、期待結果、境界の判断** を短く明示する

## 基本原則

- **先に表、後でコード**
- **Entity 層テストは pure なユニットテストを第一候補にする**
- **単一 Entity の不変条件、状態遷移、値検証、デコード/復元を優先して拾う**
- **観点は「正常系、異常系、境界値、状態遷移、不変条件、正規化、デコード、回帰」を基本セットにする**
- **副作用、Effect、Action 流れ、外部 API 呼び出しは Feature (Reducer) 側を疑う**
- **モック前提の設計にしない。必要なら小さな fake / fixture を優先する**
- **項目表は「入力分類」より「守るべきルール」が見える形にする**
- **ユーザーの明示承認があるまで、テストコードは作らない**

## 最初に確認する

1. ユーザーが求めているのは **項目表の作成** か **コード生成** か
2. 対象は値オブジェクト相当の `struct`、状態を持つ `struct`、状態 `enum`、ドメインロジックを持つ extension のどれか
3. 親ディレクトリの `.md` 仕様 (`../requirements.md`、`../state-transition.md` 等) に、用語、状態遷移、ユースケースが書かれているか
4. それは本当に Entity test か。Feature (Reducer) や Repository の責務が混ざっていないか
5. 既存の Entity やテストがあるなら、そこに命名やケース粒度の流儀があるか

必要情報が不足する場合は、推測で埋め切らず、前提を明示して確認する。

## 作業の入口

### 1. 項目表を作る

- まず親プロジェクトの `CLAUDE.md`、`./CLAUDE.md`、`./ARCHITECTURE.md` を確認する
- 局所的な値型の相談などで、仕様文書や境界判断に影響しない場合は、確認範囲を絞ってよい。その場合は前提に明記する
- 必要に応じて `swift-api-design-guidelines-skill` と `swift-testing-pro` skill を確認する
- ユーザー入力、添付ファイル、親プロジェクトの `.md` 仕様、対象コードから材料を集める
- 下記の 8 観点を基準に、必要な観点だけを洗い出す

必要なら、`Equatable` / `Hashable` の同値性や冪等性は上の 8 分類のどこに属するかを明示したうえで、
補助観点として備考列や補足へ出してよい。

### 2. 項目表を修正する

- ユーザー指摘を受けたら、表の行を追加、削除、統合、分割する
- 修正時は「何を変えたか」を短く添える

### 3. テストコードを作る

- 承認済み項目表を source of truth として扱う
- Swift Testing の parameterized test (`@Test(arguments:)`) を基本にする
- 1 ケース 1 ルールを意識し、過剰なケース統合を避ける
- Entity が他の Entity に依存する場合も、まず fixture / fake で閉じられないかを確認する
- 依存が増えすぎる場合は、Entity ではなく Feature (Reducer) 責務の可能性を先に報告する

### 承認の判定

- 次段階へ進む条件は、**直前に提示した項目表に対する明示承認** があること
- 明示承認の例: `OK`, `いいよ`, `進めて`, `LGTM`, `これでテストコードを書いて`, `表はこれでよい`
- 表を修正したあとは、**修正版に対して改めて承認** を取る
- いきなりコード作成を求められても、直前の項目表が未承認なら、項目表を再提示または要約して確認する
- 承認が曖昧なら、コード化へ進まず 1 文で確認する

## 項目表の作り方

### 推奨カラム

次の列を基本形とする。

| No | 対象 | 観点 | 事前状態/入力 | 操作 | 期待結果 | 備考 |
|---|---|---|---|---|---|---|
| 1 |  |  |  |  |  |  |

### 観点の優先順位

基本の観点分類は次の 8 つとする。

1. 正常系
2. 異常系
3. 境界値
4. 状態遷移
5. 不変条件
6. 正規化
7. デコード
8. 回帰

対象に関係ない観点は省略してよい。
ただし、使わない観点と使う観点が読んで分かるようにする。

ここでいう「優先」は、**どの観点を省略しにくいか** を示す目安であり、
表の行順そのものを決めるルールではない。

- 値型 (`struct` の値オブジェクト相当): 正常系、異常系、境界値、正規化、回帰を優先し、必要なら同値性を補足する
- 状態を持つ Entity (`struct` + 状態): 正常系、異常系、状態遷移、不変条件、回帰を優先する
- 状態 `enum`: 正常系、状態遷移、不変条件、回帰を優先する。`enum` の網羅性は Swift コンパイラが助けるので、テストでは「禁止遷移」「変換ロジック」を中心に扱う
- ドメインロジック extension / computed property: 正常系、異常系、不変条件相当の業務判定、回帰を優先し、Reducer 責務が混ざらないかを確認する

### 表の出し方

- 先に 1 行で対象と前提を書く
- その下に Markdown 表を置く
- 表の行は、基本として **正常系 → 異常系 → 境界値 → 状態遷移 → 不変条件 → 正規化 → デコード → 回帰** の順にまとめる
- 表の行順は **観点の分類順を優先** し、同じ観点の中では同じ操作や同じ生成入口ごとに寄せて並べる
- 表の下に、今回使った観点の意味を 1 行ずつ短く補足してよい
- 表の後に、**Entity / Feature / Repository の境界で除外した項目** があれば短く書く

### 観点の短い説明

表の下に補足を書く場合は、次のように短く説明する。

- 正常系: 業務上想定された正しい入力や状態で、期待した結果になること
- 異常系: 不正な入力や禁止された状態で、適切に失敗すること (`init` の throws、戻り値 `nil`、`Result` の failure など)
- 境界値: 最小値、最大値、直前直後など、境目で挙動が変わりやすい条件を確かめること
- 状態遷移: ある状態から別の状態へ、許可された遷移だけが行えること
- 不変条件: 操作の前後を通じて、常に守られるべき業務ルールが壊れないこと
- 正規化: 入力値を trim、小文字化、形式統一などで期待する表現へ整えること
- デコード: `Codable` 等を通じて、API レスポンスや永続化データから安全に Entity を再構成できること
- 回帰: 過去バグや仕様誤解が再発しないこと

## コード生成のルール

- 先に表との対応関係を確認する
- テスト名は業務ルールが読める形にする (`#expect` の前にコメントで意図を残してもよい)
- `test1`, `case1` のような名前は使わない
- `Error` の文言比較に頼りすぎず、独自エラー型 (`enum ... : Error`) で `#expect(throws: SomeError.invalidFormat)` のように比較する
- Entity の内部表現ではなく、公開 API と振る舞いを優先して確認する
- 副作用や呼び順の検証に寄り始めたら、Entity test として適切かを見直す
- async / await が出てきたら、まず Entity の責務として正しいかを再確認する

## してはいけないこと

- いきなりテストコードを書き始めること
- 8 分類を機械的にすべて埋め、対象に不要な観点まで増やすこと
- `正常系 / 異常系 / 境界値` だけで表を埋め、業務ルールを見えなくすること
- Feature (Reducer) や Repository の責務を Entity test の項目表へ混ぜること
- モックの呼び出し回数確認を中心にした brittle な Entity test を作ること
- Repository / API 通信や Supabase SDK の正しさを Entity test に背負わせること
- ユーザー承認前に「表は仮でいいから」とコード化へ進むこと

## 回答テンプレート

### 項目表を返すとき

1. **対象**: 何のテスト項目表か
2. **前提**: どの情報を根拠にしたか (親プロジェクトの仕様、対象コード、既存テスト)
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
2. どのファイルへ何のテストを作るか示す (`PLAIROOM-iOSTests/Features/...` 配下に置くか、Entity 単独のテストファイルにするか)
3. 実装後に、表の各観点をどこまでカバーしたかを短く報告する

## 追加資料

- TCA でのテスト方針: `anthropic-skills:tca` skill
- Swift Testing の書き方: `swift-testing-pro` skill
- Swift API 設計指針: `swift-api-design-guidelines-skill` skill
- 例: [examples.md](examples.md)
