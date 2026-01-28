---
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task
argument-hint: "instruction" or --session ID
description: Start a new autonomous session or resume an existing one
model: opus
---

# CRITICAL: YOU ARE A SESSION LAUNCHER

**あなたはセッション起動装置です。開発者ではありません。**

## 絶対禁止事項

- 指示テキストの内容を読んで理解・分析・実行してはいけない
- コードベースの調査をしてはいけない
- コードを書いたり修正したりしてはいけない
- 実装計画を立ててはいけない
- CEO以外のエージェントを自分で起動してはいけない

指示テキストはCEOに渡すためのデータです。あなたのタスクではありません。

## あなたの唯一の仕事

以下のbashコマンドを**そのまま実行**して、結果をユーザーに報告して**即座に終了**すること。

---

# /ad:run - Auto Dev Session Launcher

## 引数の解釈

```
/ad:run "instruction"     → Case A: 新規セッション
/ad:run --session ID      → Case B: セッション再開
/ad:run                   → Case C: セッション一覧
```

## Case A: 新規セッション

引数に指示テキストが渡された場合、以下のbashコマンドを**順番にそのまま実行**してください。

### Step 0: プラグインディレクトリの取得

```bash
AD_PLUGIN_DIR=$(cat .auto-dev/plugin-dir)
```

この `$AD_PLUGIN_DIR` を以降のスクリプト呼び出しで使う。

### Step 1: セッションID生成とディレクトリ作成

```bash
SESSION_ID=$(date +%s | md5 | head -c 8)
mkdir -p .auto-dev/sessions/$SESSION_ID/{blackboard,escalations,implementation,pr,logs}
```

### Step 2: 指示テキストの保存

`$INSTRUCTION` には引数で渡された指示テキストを代入してください。

```bash
echo "$INSTRUCTION" > .auto-dev/sessions/$SESSION_ID/instruction.txt
```

### Step 3: セッション状態の初期化

```bash
cat > .auto-dev/sessions/$SESSION_ID/session.json << EOF
{
  "session_id": "$SESSION_ID",
  "instruction": "$INSTRUCTION",
  "status": "starting",
  "phase": "init",
  "started_at": "$(date -Iseconds)",
  "updated_at": "$(date -Iseconds)"
}
EOF
```

### Step 4: tmux Windowの作成

```bash
WINDOW_NUM=$(bash "$AD_PLUGIN_DIR/scripts/dashboard.sh" ad_new_window "$SESSION_ID" "$INSTRUCTION")
```

### Step 5: CEOの起動（新しいWindowのpane 0で実行）

```bash
bash "$AD_PLUGIN_DIR/scripts/spinup.sh" "$SESSION_ID" ceo \
  "Instruction from God: $INSTRUCTION. Working directory: .auto-dev/sessions/$SESSION_ID/" \
  --initial
```

### Step 6: タイトル生成（必ずバックグラウンドで実行）

**絶対に `&` を付けてバックグラウンド実行すること。同期実行してはならない。**
タイトル完成後、自動的に `title.txt` に保存され tmux window 名が更新される。

```bash
bash "$AD_PLUGIN_DIR/scripts/gen-title.sh" "$SESSION_ID" "$INSTRUCTION" &
```

### Step 7: ユーザーへの報告（これで完了。他に何もしない）

```bash
TMUX_SESSION=$(cat .auto-dev/tmux-session)
echo "Session $SESSION_ID started in tmux window $WINDOW_NUM"
echo "Use: tmux select-window -t $TMUX_SESSION:$WINDOW_NUM"
```

**ここで終了。指示テキストの内容に取り掛かってはいけない。**

---

## Case B: セッション再開

`--session ID` が指定された場合:

```bash
AD_PLUGIN_DIR=$(cat .auto-dev/plugin-dir)

if [[ ! -d ".auto-dev/sessions/$SESSION_ID" ]]; then
  echo "Session $SESSION_ID not found"
  exit 1
fi

SESSION_JSON=$(cat .auto-dev/sessions/$SESSION_ID/session.json)
INSTRUCTION=$(echo $SESSION_JSON | jq -r '.instruction')
PHASE=$(echo $SESSION_JSON | jq -r '.phase')

# Find or create tmux window
WINDOW_NUM=$(tmux list-windows -t "$(cat .auto-dev/tmux-session)" -F '#{window_index}|#{window_name}' | grep "${SESSION_ID:0:20}" | head -1 | cut -d'|' -f1)
if [[ -z "$WINDOW_NUM" ]]; then
  WINDOW_NUM=$(bash "$AD_PLUGIN_DIR/scripts/dashboard.sh" ad_new_window "$SESSION_ID" "$INSTRUCTION")
fi

bash "$AD_PLUGIN_DIR/scripts/spinup.sh" "$SESSION_ID" ceo \
  "Session resumed. Previous phase: $PHASE. Working directory: .auto-dev/sessions/$SESSION_ID/. Check session.json and blackboard/ to continue." \
  --initial

echo "Session $SESSION_ID resumed in tmux window $WINDOW_NUM"
```

**ここで終了。**

---

## Case C: セッション一覧

引数なしの場合:

```bash
echo "Available Sessions:"
echo "==================="

for dir in .auto-dev/sessions/*/; do
  if [[ -d "$dir" ]]; then
    SID=$(basename "$dir")
    if [[ -f "${dir}session.json" ]]; then
      STATUS=$(jq -r '.status' "${dir}session.json")
      PHASE=$(jq -r '.phase' "${dir}session.json")
      if [[ -f "${dir}title.txt" ]]; then
        INST=$(cat "${dir}title.txt")
      else
        INST=$(head -c 40 "${dir}instruction.txt")
      fi
      echo "  [$SID] $STATUS ($PHASE)"
      echo "    \"$INST\""
    fi
  fi
done

echo ""
echo "To resume: /ad:run --session <ID>"
```
