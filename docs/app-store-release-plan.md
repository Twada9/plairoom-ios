# PLAIROOM iOS App Store リリース準備 計画書

## Context（背景）

PLAIROOM は AI 画像/音楽生成 + UGC（ユーザー生成コンテンツ）SNS の iOS アプリで、Apple App Store への提出を予定している。リポジトリ調査の結果、リリースに必要な以下が**ほぼ全て未整備**であることが判明した。

- 利用規約・プライバシーポリシー（`SettingsView.swift` 内のリンクは `https://example.com/privacy` `/terms` のダミー URL）
- UGC アプリに必須の通報・ブロック・モデレーション機能
- ATT（App Tracking Transparency）プロンプト（AdMob 利用中）
- PrivacyInfo.xcprivacy（Privacy Manifest）
- アプリアイコン画像本体（`Contents.json` のみ）・LaunchScreen
- アカウント削除機能（Apple がアカウント作成可能アプリに必須要求）
- Info.plist の Usage Description / Export Compliance
- Deployment Target が `iOS 26.1` で実在しないバージョン

収益モデルは **AdMob リワード広告 + アプリ内課金（プレミアム）併用**、配信地域は**全世界（GDPR/CCPA 対応必須）**。

法的文書のドラフトは別ファイルに分離している。

- 利用規約: [`docs/legal/terms-of-service.md`](./legal/terms-of-service.md)
- プライバシーポリシー: [`docs/legal/privacy-policy.md`](./legal/privacy-policy.md)

---

## 1. Apple 審査要件サマリ（Review Guidelines 別）

### 1.1 Guideline 1.2 ユーザー生成コンテンツ — 最重要

UGC を扱う以上、Apple は **以下 4 点セットが揃っていないと無条件で Reject** する。

| # | 要件 | PLAIROOM 現状 | 対応 |
|---|---|---|---|
| A | コンテンツのフィルタリング機構 | ❌ 未実装 | 投稿前のテキスト NG ワード + 画像生成プロンプトの不適切語検査 + AI 出力 NSFW 検査（Edge Function） |
| B | ユーザーによる通報機能 | ❌ 未実装 | コンテンツ・ユーザー単位の Report UI + `reports` テーブル |
| C | ユーザー単位のブロック機能 | ❌ 未実装 | `blocks` テーブル + RLS でブロック対象を非表示 |
| D | 24h 以内対応の公開窓口 | ❌ 未実装 | サービス専用メールを規約・ポリシー・アプリ内・App Store Connect に明記 + 内部運用 SLA |

> **連絡窓口メール（確定）**: `wadachiapp@gmail.com`。サポート対応・通報対応・プライバシー/データ削除請求をすべてこの 1 アドレスに集約する。規約・プライバシーポリシー・アプリ内設定・App Store Connect の全てで同一アドレスを使用する。

加えて AI 生成 SNS 特有のリスクとして「実在人物の顔・未成年の性的表現・暴力的画像」を生成させないモデレーションを Edge Function 側に組み込む。

### 1.2 Guideline 2.1 App 完全性
- ダミー URL（`example.com/privacy`, `example.com/terms`）を本番公開 URL に差し替え
- Review Notes 用のテストアカウント（メアド・パスワード・プレミアム状態）を Demo として準備
- Supabase が常時稼働、ゲスト閲覧可能範囲も明示

### 1.3 Guideline 3.1.1 アプリ内課金
- プレミアムプラン課金は **必ず StoreKit 経由**（Stripe・Web 課金への外部リンク不可）
- リワード広告で生成回数を増やすのは IAP 規制外（仮想通貨化しないこと）
- **判断**: IAP 実装が間に合わない場合、初版リリースでは `SettingsView` のプレミアム導線を「準備中」表記に留め、アップグレード導線自体を一旦削除する選択肢を採用（後続バージョンで StoreKit 2 + Edge Function でレシート検証を導入）

### 1.4 Guideline 3.2 ビジネス
- AdMob リワード広告利用を App Privacy で開示、年齢 17+ で配信、「広告視聴で回数獲得」と明示 UI

### 1.5 Guideline 4.0 デザイン
- AppIcon 1024×1024（light/dark/tinted の 3 種）と LaunchScreen の設定が物理的に必須

### 1.6 Guideline 5.1 プライバシー
- プライバシーポリシー URL を App Store Connect とアプリ内の両方からアクセス可能に
- ATT プロンプトと `NSUserTrackingUsageDescription` 必須（AdMob 使う以上）
- PrivacyInfo.xcprivacy 必須（2024 年以降）
- アカウント削除機能必須（Auth + 投稿/画像/音楽/コメント/ストレージの cascade 削除）
- カメラ/写真ライブラリ/マイク等の Usage Description

### 1.7 Guideline 5.2 知的財産
- AI 生成物の権利帰属を利用規約で明示（ユーザー利用権 + サービス側に表示用ライセンス）
- 第三者の著作権侵害プロンプト（実在キャラ・著名人）禁止
- DMCA 申請窓口（メール）

### 1.8 Guideline 5.3 ギャンブリング
- リワード広告で「ガチャ」「賞金」を出さないこと（生成回数追加のみなら影響なし）

---

## 2. App Store Connect 登録必須情報

- **App 情報**: 名称 / サブタイトル / プライマリカテゴリ（推奨: Photo & Video もしくは Social Networking）
- **価格と配信**: 無料 + IAP、全世界配信（中国本土・韓国は別途規制注意）
- **年齢区分**: **17+**（UGC + ユーザー間コミュニケーション + 不特定コンテンツ）
- **App Privacy (Nutrition Label)** 登録カテゴリ:
  - Identifiers（User ID, Device ID）
  - Usage Data（Product Interaction）
  - Diagnostics（Crash Data, Performance Data）
  - User Content（Photos, Audio, Other User Content）
  - Contact Info（Email）
  - Purchases（IAP 導入時）
  - Tracking: **Yes**（AdMob 使用のため）
- **スクリーンショット**: 6.9 inch (iPhone 16 Pro Max) 必須、6.5 inch 推奨。最低 3 枚、推奨 5 枚（AI 生成画面 / ルーム一覧 / 生成結果 / コミュニティ / 設定）
- **Review Notes**: テスト用アカウント、AI 生成が外部 API 依存、リワード広告のテスト方法
- **輸出規制**: HTTPS のみ → `ITSAppUsesNonExemptEncryption = false` を Info.plist に追加

---

## 3. コード / 設定の必須修正項目

### 3.1 Xcode プロジェクト設定（`PLAIROOM-iOS.xcodeproj/project.pbxproj`）
- `IPHONEOS_DEPLOYMENT_TARGET = 26.1` → **iOS 17.0 もしくは 18.0 へ引き下げ**（TCA / SwiftUI / Supabase SDK は 17 で動作。最新 OS だけだとユーザー基盤が極端に小さい）
- `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1` を初回審査用に確定

### 3.2 Info.plist 追加項目（`PLAIROOM-iOS/Info.plist`）
- `NSUserTrackingUsageDescription`（例: 「広告の関連性を高めるため、トラッキングの許可をお願いします」）
- `NSPhotoLibraryUsageDescription` / `NSPhotoLibraryAddUsageDescription`（生成画像の保存 UI を出すなら）
- `NSCameraUsageDescription` / `NSMicrophoneUsageDescription`（必要時のみ）
- `ITSAppUsesNonExemptEncryption = false`
- `UILaunchScreen`（Dictionary） or `UILaunchStoryboardName`
- `CFBundleDisplayName = "PLAIROOM"`
- `LSApplicationCategoryType`

### 3.3 PrivacyInfo.xcprivacy（新規 `PLAIROOM-iOS/PrivacyInfo.xcprivacy`）
- `NSPrivacyTracking = true`
- `NSPrivacyTrackingDomains`: `googleads.g.doubleclick.net`, `googleadservices.com`, `googlesyndication.com` 他 AdMob ドメイン
- `NSPrivacyCollectedDataTypes`: App Store Connect の Nutrition Label と完全一致させる
- `NSPrivacyAccessedAPITypes`:
  - UserDefaults（理由 `CA92.1`）
  - File timestamp（`C617.1`）
  - System boot time（`35F9.1`）
  - Disk space（`E174.1`）

### 3.4 AppIcon / LaunchScreen
- 1024×1024 PNG（角丸なし、アルファ無し）を **light / dark / tinted** の 3 種で配置し `Contents.json` の `filename` フィールドを更新
- LaunchScreen はロゴ + 背景色のみのシンプル構成

### 3.5 SettingsView の差し替え（`Features/Settings/SettingsView.swift`）
- `https://example.com/privacy` / `https://example.com/terms` を本番 URL に差し替え
- 追加リンク: 「アカウント削除」「お問い合わせ」「データ削除リクエスト」「サブスクリプション管理」（App Store の subscriptions スキーマ）

### 3.6 ATT プロンプト
- `PLAIROOM_iOSApp.swift` で AdMob 初期化前に `ATTrackingManager.requestTrackingAuthorization` を呼ぶ
- `RewardedAdClient.swift` で ATT 結果に応じて Non-Personalized Ads に切り替え

---

## 4. 実装が必要な機能

| # | 機能 | 概要 | 配置先 | 満たす審査要件 |
|---|---|---|---|---|
| F1 | 通報機能 | コンテンツ/ユーザー通報。理由分類（性的/暴力/著作権/スパム/その他）。`reports` テーブル新設 | `Features/Report/` 新規 | 1.2-B |
| F2 | ブロック機能 | ユーザー単位ブロック。`blocks` テーブル新設。RLS でブロック対象を非表示 | `Repository/BlockRepository.swift` 新規 | 1.2-C |
| F3 | アカウント削除 | Supabase Edge Function `delete_account` で Auth + 関連データ cascade 削除 | `SettingsFeature.swift` 拡張 | 5.1 |
| F4 | 規約同意フロー | 初回起動 + 改訂時に利用規約・プライバシーポリシーへの同意取得 | `Features/Onboarding/Consent/` 新規 | 5.1 |
| F5 | ATT プロンプト | AdMob 初期化前に呼び出し | `PLAIROOM_iOSApp.swift` | 5.1 |
| F6 | NSFW モデレーション | プロンプト/出力をモデレーション API（OpenAI Moderation 等）で検査 | Edge Function 側 | 1.2-A |
| F7 | 問い合わせ導線 | 24h 対応用 mailto: リンク | `SettingsView.swift` | 1.2-D |
| F8 | IAP（後続） | StoreKit 2 + Edge Function レシート検証 | `Features/Paywall/` 新規 | 3.1.1 |

---

## 5. 優先順位とフェーズ分け

### Phase 0: リリース前必須（これが揃わないと審査落ち）
- AppIcon / LaunchScreen / Deployment Target / Bundle 設定
- Info.plist Usage Description 一式 + Export Compliance
- PrivacyInfo.xcprivacy 配置
- 利用規約・プライバシーポリシー Web 公開 + アプリ内リンク本番化
- 通報 / ブロック / アカウント削除（UGC 3 点セット）
- ATT 実装
- App Store Connect 情報入力（Privacy ラベル / 17+ / Demo Account）
- ダミー文言の排除

### Phase 1: リリース推奨（落ちる可能性を下げる）
- NSFW モデレーション自動化
- Sign in with Apple（メール以外のソーシャルログイン導入時は必須）
- 規約同意フロー UI
- お問い合わせ自動応答テンプレート

### Phase 2: ポストリリース可
- IAP プレミアム購入（実装まで時間がかかる場合は導線ごと一旦削除）
- 英語ローカライズ（全世界配信のため将来必須）
- 詳細モデレーションダッシュボード
- DMCA 申請フォーム Web 化

---

## 6. 検証方法

- **Xcode Validate App**: Archive 後の Validate でアイコン欠落・Privacy Manifest 整合性・Missing Capabilities を検出
- **Privacy Report**: Product → Privacy Report で「使用 API と理由コード」「サードパーティ SDK のドメイン」を確認
- **App Privacy 整合性**: App Store Connect の Nutrition Label / PrivacyInfo.xcprivacy / 実装の 3 者が一致しているか
- **TestFlight 内部テスト**: 最低 5 名で 1 週間検証。クラッシュ率 < 1% 目標
- **Reject されやすいチェック項目**:
  - UGC 4 点セットが揃っているか
  - ダミー URL が残っていないか
  - アカウント削除が実際に動作するか
  - ATT プロンプトのタイミング（最初の利用時）
  - IAP 導線が外部リンクへ飛んでいないか

---

## 7. 修正対象ファイル一覧（実装フェーズで触る）

- `PLAIROOM-iOS/Info.plist`（Usage Description / Export Compliance / LaunchScreen）
- `PLAIROOM-iOS/Assets.xcassets/AppIcon.appiconset/`（画像配置 + Contents.json）
- `PLAIROOM-iOS.xcodeproj/project.pbxproj`（Deployment Target、PrivacyInfo.xcprivacy 参照）
- `PLAIROOM-iOS/Features/Settings/SettingsView.swift` / `SettingsFeature.swift`
- `PLAIROOM-iOS/PLAIROOM_iOSApp.swift`（ATT + AdMob 初期化順序）
- `PLAIROOM-iOS/Features/RewardedAdClient.swift`（Non-Personalized Ads 切り替え）
- 新規: `PLAIROOM-iOS/PrivacyInfo.xcprivacy`
- 新規: `PLAIROOM-iOS/Features/Report/`
- 新規: `PLAIROOM-iOS/Features/Block/` または `Repository/BlockRepository.swift`
- 新規: `PLAIROOM-iOS/Features/Onboarding/Consent/`

---

## 8. チェックリスト

- [ ] AppIcon 1024×1024（light/dark/tinted）配置
- [ ] LaunchScreen 設定
- [ ] Info.plist Usage Description 一式
- [ ] PrivacyInfo.xcprivacy 配置
- [ ] ITSAppUsesNonExemptEncryption 設定
- [ ] Deployment Target を実在バージョンへ引き下げ
- [ ] 利用規約 / プライバシーポリシー Web 公開
- [ ] アプリ内リンク本番化（SettingsView の example.com 撤去）
- [ ] 通報機能実装
- [ ] ブロック機能実装
- [ ] アカウント削除実装
- [ ] ATT 実装
- [ ] NSFW モデレーション
- [ ] App Store Connect: Privacy Label / 年齢 17+ / スクリーンショット / Demo Account
- [ ] TestFlight 検証
- [ ] Xcode Validate App 成功

---

## 9. 次のアクション

1. 本計画書のレビューと承認
2. 連絡窓口メール `wadachiapp@gmail.com` の受信体制を整備（24h 対応運用ルール策定）
3. Phase 0 タスクの ticket 化（GitHub Issues / Notion）
4. 法務レビュー（利用規約・プライバシーポリシー文面）
5. 規約・ポリシーの公開先 Web ページ用意（GitHub Pages or 専用ドメイン）
6. App Store Connect での App レコード作成と Demo Account 払い出し
7. 通報 / ブロック / アカウント削除 の TCA Feature をテスト項目表から着手
