# 实现计划：客户工单排查 Agent Team Skill

> 设计文档: `docs/plans/2026-03-12-ticket-investigation-team-design.md`
> 日期: 2026-03-12

---

## 实现步骤

### Step 1: 创建项目基础结构

创建以下目录和文件：

```
/h/AI/troubleshooteam/
├── .claude/
│   ├── agents/                          # Agent 定义目录
│   │   ├── issue-analyst.md
│   │   ├── investigation-planner.md
│   │   ├── kusto-author.md
│   │   ├── kusto-executor.md
│   │   ├── devops-searcher.md
│   │   └── doc-searcher.md
│   ├── commands/                        # Skill 命令目录
│   │   └── investigate.md               # /investigate 入口
│   └── settings.json                    # 项目级设置（MCP 预留）
├── config/
│   ├── adx-clusters.json               # ADX 集群配置（可热更新）
│   ├── devops-projects.json            # DevOps 项目配置
│   └── agent-tools.json                # Agent MCP/Skills 配置（扩展点）
├── templates/
│   └── report-template.md              # 排查报告模板
└── docs/
    └── plans/
        ├── 2026-03-12-ticket-investigation-team-design.md
        └── 2026-03-12-implementation-plan.md (本文件)
```

### Step 2: 创建 Agent 定义文件（6 个）

每个 Agent 定义为 `.claude/agents/<name>.md`，包含：
- Front matter（name, description, tools）
- System prompt（角色说明、输出格式要求）
- MCP/Skills 预留区（注释占位）

**顺序：** issue-analyst → investigation-planner → kusto-author → kusto-executor → devops-searcher → doc-searcher

### Step 3: 创建配置文件

- `config/adx-clusters.json` — ADX 集群地址、数据库名、常用表（占位，用户后续填入）
- `config/devops-projects.json` — Azure DevOps 组织、项目、Wiki 名称（占位）
- `config/agent-tools.json` — 每个 Agent 的 MCP 工具和 Skills 映射（扩展点）

### Step 4: 创建 /investigate Skill 入口

`.claude/commands/investigate.md` 包含：
- 接收用户输入（工单描述）
- TeamCreate 编排逻辑
- 4 阶段调度流程
- 报告生成和团队清理

### Step 5: 创建报告模板

`templates/report-template.md` — 标准化排查报告格式

### Step 6: 测试与验证

- 用模拟工单测试完整流程
- 验证各 Agent 通信正常
- 验证报告输出格式

---

## 关键设计决策

1. **Agent 定义用 `.md` 文件** — 符合 Claude Code agents 规范，易于编辑
2. **配置与代码分离** — `config/` 目录存放环境相关配置，更换环境只需改配置
3. **MCP/Skills 预留用注释占位** — 每个 Agent 文件中明确标注扩展点，后续添加无需改结构
4. **报告模板独立** — 方便定制不同格式的报告

---

## 实施顺序

```
Step 1 (基础结构) → Step 2 (Agent 定义) → Step 3 (配置文件)
                                              ↓
                 Step 6 (测试) ← Step 5 (报告模板) ← Step 4 (Skill 入口)
```

Step 2 中的 6 个 Agent 可并行创建。
