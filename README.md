# Auto Dev Plugin (ad)

曖昧な指示から自律的に開発を進める、階層型マルチエージェントシステム。

## 概要

「認証を改善して」のような曖昧な指示を投げるだけで、CEO・VP・メンバーという会社組織のようなエージェント群が自律的に動き、仕様策定からPR作成・レビュー対応まで行います。

```
あなた (God)
    ↓ 曖昧な指示
   CEO (指示を解釈・統括)
  / | \
 VP  VP  VP (各部門を統括)
 |   |   |
PM  UX  Dev (調査・実装)
```

## 必要要件

- **Claude Code CLI** (claude コマンドが使える状態)
- **tmux** (マルチペイン管理用)
- **macOS** (通知機能用。Linux でも動作しますが通知は出ません)

## インストール

### 方法1: Claude Code のプラグインとして使う (推奨)

```bash
# 1. リポジトリをクローン
git clone https://github.com/ken2403/claude-auto-dev-plugin.git

# 2. 作業したいプロジェクトに移動
cd your-project-directory

# 3. プラグインを有効化 (シンボリックリンク作成)
ln -s /path/to/claude-auto-dev-plugin/.claude-plugin .claude-plugin

# 4. CLAUDE.md もリンク (オプション)
ln -s /path/to/claude-auto-dev-plugin/CLAUDE.md .claude/plugins/auto-dev.md
```

### 方法2: プロジェクト内にコピー

```bash
# リポジトリをクローン
git clone https://github.com/ken2403/claude-auto-dev-plugin.git

# プロジェクトにコピー
cp -r claude-auto-dev-plugin/.claude-plugin your-project/.claude-plugin
cp -r claude-auto-dev-plugin/roles your-project/.claude-plugin/roles
cp -r claude-auto-dev-plugin/agents your-project/.claude-plugin/agents
cp -r claude-auto-dev-plugin/scripts your-project/.claude-plugin/scripts
cp -r claude-auto-dev-plugin/commands your-project/.claude-plugin/commands
cp -r claude-auto-dev-plugin/skills your-project/.claude-plugin/skills
cp -r claude-auto-dev-plugin/templates your-project/.claude-plugin/templates
cp -r claude-auto-dev-plugin/hooks your-project/.claude-plugin/hooks
```

### インストール確認

```bash
# Claude Code を起動
cd your-project-directory
claude

# プラグインが認識されているか確認
/ad:status
```

`/ad:status` が動けばインストール成功です。

## クイックスタート

### 1. 初期化 (初回のみ)

```bash
cd your-project-directory
bash path/to/claude-auto-dev-plugin/scripts/dashboard.sh ad_init
```

tmuxセッション `auto-dev` が起動し、Command Center (window 0) が開きます。

### 2. 指示を投げる

Command Center で以下を実行:

```bash
/ad:run "認証機能を改善して"
```

これだけで:
1. 新しいセッションID が生成される
2. 新しい tmux window が作成される
3. CEO が起動し、指示を解釈して VP たちを召集
4. あなたは Command Center に即座に戻り、別の作業が可能

### 3. 進捗確認

```bash
/ad:status
```

全セッションの状態、アクティブなエージェント、進捗を確認できます。

### 4. エスカレーション対応

CEO が判断を求めてきたら **macOS通知** が届きます。

```bash
# エスカレーション一覧を確認
/ad:ans SESSION_ID

# 回答する
/ad:ans SESSION_ID "TOTPのみでOK。SMSは後回しで。"
```

### 5. クリーンアップ

完了したセッションを削除:

```bash
/ad:cleanup
```

## コマンド一覧

| コマンド | 説明 |
|---------|------|
| `/ad:run "指示"` | 新しいセッションを開始 |
| `/ad:run --session ID` | 既存セッションを再開 |
| `/ad:run` | 中断セッション一覧から選択して再開 |
| `/ad:status` | 全セッションの状態を表示 |
| `/ad:ans SESSION_ID` | エスカレーション一覧を表示 |
| `/ad:ans SESSION_ID "回答"` | エスカレーションに回答 |
| `/ad:cleanup` | 完了セッション・worktree を削除 |

## 使用例

### 例1: 新機能の追加

```bash
/ad:run "ユーザーにMFA (多要素認証) を追加して"
```

CEO が自動的に:
- VP Product に要件調査を依頼
- VP Design に UX 設計を依頼
- VP Engineering に技術調査を依頼
- 統合して仕様書作成
- QA チームによるレビュー
- PR 作成
- Review Sentinel によるレビューコメント自動対応

### 例2: バグ修正

```bash
/ad:run "ログインページで500エラーが出るバグを修正して"
```

CEO が判断して:
- VP Engineering だけを召集 (軽微な修正と判断)
- 技術調査 → 修正 → QA → PR

### 例3: 調査のみ

```bash
/ad:run "現在の認証フローを調査してまとめて"
```

CEO が判断して:
- 必要な VP を召集
- 調査結果をまとめて報告
- 実装は行わない

## tmux ウィンドウ構成

```
┌─────────────────────────────────────────────────────────┐
│ window 0: COMMAND CENTER                                │
│  ここで /ad:run を叩く。常に受付可能。                   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ window 1: Session "認証改善" (session_id: abc123)       │
│ ┌────────┬────────┬────────┬────────┐                  │
│ │  CEO   │VP Prod │VP Dsgn │VP Eng  │                  │
│ │        ├────────┼────────┤        │                  │
│ │        │ PM-1   │  UX    │ Dev-1  │                  │
│ │        │ PM-2   │  IA    │ Dev-2  │                  │
│ └────────┴────────┴────────┴────────┘                  │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ window 2: Session "バグ修正" (session_id: def456)       │
│ ┌────────┬────────┐                                    │
│ │  CEO   │Builder │  ← 軽微修正は CEO が直接 Builder 起動│
│ └────────┴────────┘                                    │
└─────────────────────────────────────────────────────────┘
```

## エスカレーション

CEO は以下の場合のみ人間に判断を求めます:

| 状況 | 例 |
|------|-----|
| 指示が曖昧すぎる | 「良くして」だけでは方向性が不明 |
| VP 間の矛盾が解決できない | Product と Engineering で意見が対立 |
| 重大なビジネス判断 | セキュリティ方針の決定 |
| 不可逆な決定 | 既存データの移行方針 |

### エスカレーションの流れ

```
1. CEO が判断を求める
   ↓
2. macOS 通知が届く (音付き)
   ↓
3. あなた: /ad:ans SESSION_ID で内容を確認
   ↓
4. あなた: /ad:ans SESSION_ID "回答" で回答
   ↓
5. CEO が回答を検知して作業続行
```

## ディレクトリ構造

セッションごとに作業ディレクトリが作成されます:

```
.auto-dev/sessions/{session_id}/
├── instruction.txt        # あなたの指示
├── session.json           # セッション状態 (再開用)
├── blackboard/            # エージェント間通信
│   ├── ceo-directive.json
│   ├── vp-product.json
│   ├── vp-design.json
│   ├── vp-engineering.json
│   └── ...
├── escalations/           # エスカレーション
│   ├── 1706234567.json
│   └── 1706234567-answer.json
├── implementation/        # 実装作業
└── pr/                    # PR 関連
```

## 組織構成

### 経営層
- **CEO**: 指示を解釈し、全体を統括。VP 間の調整、エスカレーション判断

### VP (部門長)
- **VP Product**: 要件定義、優先度決定
- **VP Design**: UX/UI 設計、デザイン判断
- **VP Engineering**: 技術方針、アーキテクチャ、実装統括

### メンバー (VP が必要に応じて召集)
- **PM-1, PM-2**: ユーザーニーズ調査、スコープ分析
- **UX, IA**: インタラクション設計、情報設計
- **Dev-1, Dev-2**: コードベース調査、技術分析
- **Builder** (N体): 実際のコード実装

### 専門チーム
- **QA Lead**: 品質監査統括 (常に2体以上の QA を召集)
  - QA-Security: セキュリティ監査
  - QA-Performance: パフォーマンス監査
  - QA-Documentation: ドキュメント監査
- **DevOps Lead**: Worktree 管理、ビルド、PR 作成
- **Review Sentinel**: PR レビューコメントの自動監視・対応

## 指示のコツ

### 良い指示

```bash
# 目的が明確
/ad:run "ユーザーがパスワードを忘れた時にリセットできる機能を追加して"

# 制約がある場合は伝える
/ad:run "ログイン画面のデザインを改善して。ただし既存のカラースキームは維持"

# 調査だけしてほしい時
/ad:run "現在の API エンドポイント一覧と認証方式をまとめて (実装は不要)"
```

### CEO が困る指示

```bash
# 曖昧すぎる (エスカレーションされる可能性)
/ad:run "良くして"

# 矛盾している
/ad:run "高速にして。でもコードは1行も変えないで"
```

## トラブルシューティング

### セッションが止まったように見える

```bash
# 状態を確認
/ad:status

# 該当 window に切り替えて CEO pane を確認
tmux select-window -t auto-dev:1
```

### エスカレーションに気づかなかった

```bash
# 全セッションのエスカレーションを確認
/ad:ans SESSION_ID
```

### やり直したい

```bash
# セッションをクリーンアップして再実行
/ad:cleanup
/ad:run "指示"
```

## 注意事項

- **tmux が必要です**: このプラグインは tmux を使用します
- **Command Center で操作**: `/ad:run` は必ず window 0 (Command Center) で実行
- **エスカレーションに応答**: CEO からの質問には `/ad:ans` で回答してください
- **並列実行可能**: 複数のセッションを同時に実行できます

## スクリプト一覧

| スクリプト | 用途 |
|-----------|------|
| `dashboard.sh ad_init` | tmux セッション初期化 |
| `adwatch.sh` | 全セッション横断モニター |
| `adlog.sh` | エージェントログ表示 |
| `spinup.sh` | エージェント起動 (内部用) |
| `teardown.sh` | クリーンアップ (内部用) |
| `escalate.sh` | エスカレーション送信 (内部用) |
| `notify.sh` | macOS 通知 (内部用) |

## ライセンス

MIT License
