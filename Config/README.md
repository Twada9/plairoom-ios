# 環境変数設定ガイド

このディレクトリには、Supabase APIキーなどの機密情報を管理するための設定ファイルが含まれています。

## セットアップ手順

### 1. Secrets.xcconfig の作成

テンプレートから実際の設定ファイルを作成します（初回のみ）：

```bash
# すでに Secrets.xcconfig が存在する場合はスキップ
cp Config/Secrets.template.xcconfig Config/Secrets.xcconfig
```

### 2. Supabase プロジェクト情報の取得

1. [Supabase Dashboard](https://app.supabase.com/) にログイン
2. プロジェクトを選択
3. **Settings** → **API** を開く
4. 以下の値をコピー：
   - **Project URL** から `PROJECT_REF` を取得（例: `https://abcdefgh.supabase.co` → `abcdefgh`）
   - **Project API keys** から `anon` `public` キーをコピー

### 3. Secrets.xcconfig の編集

`Config/Secrets.xcconfig` を開き、実際の値に置き換えます：

```xcconfig
// Supabase Project Reference ID
SUPABASE_PROJECT_REF = abcdefgh

// Supabase Anonymous Key (公開API用キー)
SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### 4. Xcode プロジェクトに .xcconfig を設定

1. Xcodeでプロジェクトを開く
2. プロジェクトナビゲータでプロジェクトルート（PLAIROOM-iOS）を選択
3. **Info** タブを開く
4. **Configurations** セクションで以下を設定：
   - **Debug** → `Debug.xcconfig`
   - **Release** → `Release.xcconfig`

## ファイル構成

```
Config/
├── README.md                      # このファイル
├── Secrets.template.xcconfig      # テンプレート（Git管理対象）
├── Secrets.xcconfig               # 実際の環境変数（Git管理対象外）
├── Debug.xcconfig                 # Debug ビルド設定
└── Release.xcconfig               # Release ビルド設定
```

## セキュリティ

- ✅ `Secrets.template.xcconfig` は Git にコミット可能（ダミー値のみ）
- ❌ `Secrets.xcconfig` は `.gitignore` に含まれており Git にコミットされません
- ⚠️ 実際のAPIキーは **絶対に** Git にコミットしないでください

## トラブルシューティング

### ビルドエラー: "SUPABASE_PROJECT_REF" が見つからない

1. `Config/Secrets.xcconfig` が存在するか確認
2. Xcode の Configurations 設定を確認
3. Xcode を再起動してプロジェクトをクリーンビルド

### アプリ実行時に空文字列が返される

1. `INFOPLIST_KEY_SUPABASE_PROJECT_REF` が `Debug.xcconfig` / `Release.xcconfig` に設定されているか確認
2. ビルド設定で Info.plist にキーが埋め込まれているか確認（Xcode の Build Settings で検索）

## コードでの使用方法

環境変数は `SupabaseConfig.shared` を通じて自動的に読み込まれます：

```swift
import Foundation

// アプリ起動時に自動的に設定値が読み込まれる
let config = SupabaseConfig.shared

print(config.projectRef)  // Secrets.xcconfig の値が表示される
print(config.anonKey)     // Secrets.xcconfig の値が表示される
```
