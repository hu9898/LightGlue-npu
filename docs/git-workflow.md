# LightGlue Git 管控说明

本文档是 `customLightGlue/LightGlue` 仓库的唯一 Git 流程说明。后续所有会话、手工修改和 Codex 修改，都应以本文档为准。

## 1. 作用范围

- Git 仅管理当前仓库：`/home/work/myProject/customLightGlue/LightGlue`
- 不在 `/home/work/myProject` 外层再创建总仓库
- 所有 Git 命令都应在本仓库根目录执行

进入仓库后，先执行：

```bash
cd /home/work/myProject/customLightGlue/LightGlue
git status --short --branch
```

如果工作区不是干净状态，先手工整理或提交，再开始新任务。

## 2. 分支与同步规则

固定规则：

- `main` 只作为同步基线，不建议直接在 `main` 上堆积长期开发改动
- 日常开发分支命名统一使用 `work/YYYYMMDD-<topic>`
- 修改前先确认当前分支和工作区状态

推荐流程：

```bash
git switch main
git pull --ff-only origin main
git switch -c work/$(date +%Y%m%d)-your-topic
```

如果分支已存在，可改用：

```bash
git switch work/$(date +%Y%m%d)-your-topic
git pull --ff-only origin main
```

## 3. 远端与 fork 说明

当前仓库默认远端通常是原始仓库或镜像仓库。同步时优先使用：

```bash
git remote -v
git fetch origin
git pull --ff-only origin main
```

如果你对 `origin` 没有推送权限，推荐添加自己的 fork 远端：

```bash
git remote add myfork <your-fork-url>
git push -u myfork <your-branch>
```

建议保留：

- `origin`：上游或当前默认源，用于同步
- `myfork`：你自己的可写远端，用于推送个人分支

## 4. 手工提交规范

手工提交信息统一使用：

```text
<type>: <summary>
```

允许的 `type` 仅限：

- `feat`
- `fix`
- `docs`
- `refactor`
- `test`
- `chore`

示例：

```bash
git add path/to/file
git commit -m "fix: handle empty descriptor inputs"
```

默认不自动推送；先在本地确认提交内容，再决定是否 `git push`。

## 5. Codex 自动存档入口

本仓库要求：当模型要直接改文件时，优先使用仓库内包装脚本，而不是直接运行普通 `codex`。

唯一受支持的自动存档入口：

```bash
scripts/codex_auto_commit.sh -m "short summary" "your prompt"
```

脚本行为固定如下：

- 启动前检查当前仓库是否干净
- 如果存在未提交改动、已暂存改动或未跟踪文件，直接失败退出
- 通过 `codex exec -C <repo-root>` 发起一次非交互任务
- 若本次任务没有改动任何文件，则不创建提交
- 若任务成功且产生改动，则自动执行一次 `git add -A` 和 `git commit -m "codex: <summary>"`
- 若任务失败但留下了改动，则仍然创建一次 `codex-wip: <summary>` 检查点提交，并保留原始失败退出码
- 脚本不会自动 `git push`

单行 prompt 示例：

```bash
scripts/codex_auto_commit.sh \
  -m "document local git workflow" \
  "Add a short development workflow section to the README and keep the wording concise."
```

多行 prompt 示例：

```bash
cat <<'EOF' | scripts/codex_auto_commit.sh -m "adjust docs wording"
Update the Chinese Git workflow document.
Keep the examples accurate for this repository.
Do not change code outside docs.
EOF
```

说明：

- 一次脚本调用，对应一次 `codex exec`
- 一次 `codex exec`，最多生成一个自动提交
- 这就是本文档中“每次模型修改时都存一次”的正式含义

## 6. 普通 Codex 与自动存档的区别

普通 `codex` 适合：

- 阅读代码
- 分析问题
- 讨论方案
- 做不需要自动提交的临时探索

普通 `codex` 不保证：

- 每轮对话自动落 Git
- 会话结束后自动创建检查点提交

因此，只要目标是“让模型改文件并自动留痕”，就应使用：

```bash
scripts/codex_auto_commit.sh
```

## 7. 为什么后续会话能快速读到这些规则

本仓库采用两层机制：

- 仓库根 `AGENTS.md`：给 Codex 的仓库级说明，优先放项目约束和工作流要求
- 可选的 `.codex/config.toml`：给本机使用者补充个人或项目级 Codex 配置

当前正式依赖的是仓库根 `AGENTS.md`。也就是说，新会话只要从仓库根启动 Codex，就应优先读到这里的 Git 规则。

如果你希望在本机补一份项目级 Codex 配置，可以创建可选文件 `./.codex/config.toml`，例如：

```toml
model = "gpt-5.4"
model_reasoning_effort = "high"

[features]
codex_git_commit = false
codex_hooks = false
```

说明：

- 上面这份配置是可选的本机偏好，不是正式流程的依赖项
- 本仓库当前不依赖实验特性 `codex_git_commit` 或 `codex_hooks`
- 正式保障来自 `AGENTS.md` 加 `scripts/codex_auto_commit.sh`

## 8. 常用检查命令

查看当前状态：

```bash
git status --short --branch
```

查看最近提交：

```bash
git log --oneline --decorate -n 10
```

查看本次改动：

```bash
git diff
git diff --staged
```

查看远端：

```bash
git remote -v
```

## 9. 禁止事项

- 不要在脏工作区里启动自动存档脚本
- 不要把自动生成的检查点提交默认视为最终提交，推送前需要复查
- 不要依赖未稳定的 Codex 实验特性代替仓库脚本
- 不要在外层 `/home/work/myProject` 新建总仓库来覆盖本仓库的 Git 历史

## 10. 参考资料

- Config basics – Codex: <https://developers.openai.com/codex/config-basic>
- Non-interactive mode – Codex: <https://developers.openai.com/codex/noninteractive>
- Custom instructions with AGENTS.md – Codex: <https://developers.openai.com/codex/guides/agents-md>
- Configuration reference – Codex: <https://developers.openai.com/codex/config-reference>
- Features – Codex CLI: <https://developers.openai.com/codex/cli/features>
