# 例

## 例1: 値型 `Email`

前提:

- ユーザーは「メールアドレス値型のテストを作りたい」と依頼
- 親プロジェクトの仕様 (`../requirements.md`) に形式要件は少なく、入力ルールはコードと依頼文から読む
- `Email` は `struct` で、`init(rawValue:) throws` を持つ想定

項目表:

| No | 対象 | 観点 | 事前状態/入力 | 操作 | 期待結果 | 備考 |
|---|---|---|---|---|---|---|
| 1 | `Email` | 正常系 | `user@example.com` | `Email(rawValue:)` | 生成成功 | 基本ケース |
| 2 | `Email` | 異常系 | 空文字 | `Email(rawValue:)` | エラー throw | 必須制約 |
| 3 | `Email` | 異常系 | `userexample.com` | `Email(rawValue:)` | エラー throw | `@` 不足 |
| 4 | `Email` | 境界値 | `a@b.cd` | `Email(rawValue:)` | 生成成功 | 最小長の妥当値の例 |
| 5 | `Email` | 境界値 | 256 文字相当のメールアドレス | `Email(rawValue:)` | エラー throw | 上限超過の例 |
| 6 | `Email` | 正規化 | `  user@example.com  ` | `Email(rawValue:)` | trim 後の値で保持 | 仕様次第 |
| 7 | `Email` | 回帰 | 過去に通ってしまった不正形式 | `Email(rawValue:)` | エラー throw | 再発防止 |

補足:

- SwiftUI の `TextField` に対する入力バリデーションが主題なら `presentation-layer-test` (View) 側を優先する
- API レスポンスに含まれる email を扱うなら、`Codable` 経由のデコードを `デコード` 観点として追加する
- この例では `デコード` を省略している。`Codable` 経由の復元を扱う場合だけ追加する

## 例2: 集約相当の Entity `Room`

前提:

- `Room` は `pending`, `active`, `closed` の状態を `enum RoomStatus` で持つ
- 部屋の参加人数や生成上限のような不変条件は `Room` 側で守る
- 状態遷移は親プロジェクトの `../state-transition.md` に基づく

項目表:

| No | 対象 | 観点 | 事前状態/入力 | 操作 | 期待結果 | 備考 |
|---|---|---|---|---|---|---|
| 1 | `Room` | 正常系 | 正常な title と上限値 | `Room(...)` | 生成成功 | 基本ケース |
| 2 | `Room` | 異常系 | title が空 | `Room(...)` | エラー throw | 必須制約 |
| 3 | `Room` | 異常系 | 上限値が 0 以下 | `Room(...)` | エラー throw | 整合性 |
| 4 | `Room` | 状態遷移 | `pending` | `activate()` | `active` になる | 正常遷移 |
| 5 | `Room` | 状態遷移 | `active` | `activate()` | エラー throw | 再アクティベート禁止 |
| 6 | `Room` | 状態遷移 | `closed` | `activate()` | エラー throw | 禁止遷移 |
| 7 | `Room` | 状態遷移 | `active` | `activate()` を再実行 | 状態を壊さない | 冪等性をこの観点で扱う例 |
| 8 | `Room` | 不変条件 | `active` で参加上限ギリギリ | `addMember(_:)` | 上限超過なら拒否、参加人数不変 | 操作後確認 |
| 9 | `Room` | デコード | Supabase 由来の正当 JSON | `JSONDecoder().decode(Room.self, ...)` | 復元成功 | DTO ↔ Entity 変換を扱う場合 |

補足:

- 通知送信や Supabase 永続化が絡むなら、その部分は `usecase-layer-test` (Feature/Reducer) の項目へ移す
- View 側で「`active` のときだけボタンを出す」のような表示判定は `presentation-layer-test` (View) 側で扱う
- この例では `回帰` を省略している。過去不具合や仕様誤解があれば、回帰行を追加する
