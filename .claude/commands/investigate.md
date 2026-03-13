# /investigate — 客户工单排查 Agent Team

接收用户输入的工单信息，自动组建排查团队，完成从问题分析到根因定位的全流程。

## 输入格式

```
/investigate <工单描述>
```

示例:
```
/investigate 工单#12345: 用户反馈从 3/10 开始 API 返回 500 错误，影响 tenant: contoso.com，主要是 /api/v2/users 接口
```

## 执行流程

收到 `/investigate` 命令后，你（作为 team-lead）按以下步骤执行：

---

### Step 0: 初始化

1. 读取配置文件：
   - `config/adx-clusters.json` — ADX 集群信息
   - `config/devops-projects.json` — DevOps 项目信息
   - `config/agent-tools.json` — Agent 扩展工具配置

2. 创建团队：
   ```
   TeamCreate("ticket-investigation", description="排查工单: <工单简述>")
   ```

3. 创建初始任务：
   ```
   TaskCreate("分析工单", description="从用户描述中提取结构化问题信息")
   ```

---

### Step 1: Phase 1 — 理解问题

启动 issue-analyst Agent：

```
Agent(
  name="issue-analyst",
  team_name="ticket-investigation",
  subagent_type="general-purpose",
  prompt="""
  你是 issue-analyst（问题分析师）。请阅读你的 Agent 定义文件 .claude/agents/issue-analyst.md 了解完整的角色说明和输出格式要求。

  请分析以下工单信息，按照你的输出 Schema 返回结构化摘要：

  --- 工单信息 ---
  {用户输入的工单描述}
  --- 结束 ---

  完成后，用 SendMessage 将结构化摘要发送给 team-lead。
  """
)
```

收到 issue-analyst 的结果后，将摘要保存，继续下一步。

---

### Step 2: Phase 2 — 制定排查计划

启动 investigation-planner Agent：

```
Agent(
  name="investigation-planner",
  team_name="ticket-investigation",
  subagent_type="general-purpose",
  prompt="""
  你是 investigation-planner（排查规划师）。请阅读你的 Agent 定义文件 .claude/agents/investigation-planner.md 了解完整的角色说明和输出格式要求。

  请根据以下问题摘要制定排查计划：

  --- 问题摘要 ---
  {issue-analyst 返回的结构化摘要}
  --- 结束 ---

  ADX 集群配置：{从 config/adx-clusters.json 读取的信息}

  请按照你的输出 Schema 返回排查计划，特别注意：
  1. 标注哪些步骤可以并行执行
  2. 为 Kusto 查询提供具体的表名和筛选条件提示
  3. 为搜索任务提供精准的关键词

  完成后，用 SendMessage 将排查计划发送给 team-lead。
  """
)
```

---

### Step 3: Phase 3 — 并行执行

根据排查计划，将任务分派给对应的 Agent。**尽可能并行启动**：

#### 3a. Kusto 查询（串行：先 author 后 executor）

```
Agent(
  name="kusto-author",
  team_name="ticket-investigation",
  subagent_type="general-purpose",
  prompt="""
  你是 kusto-author（KQL 编写专家）。请阅读你的 Agent 定义文件 .claude/agents/kusto-author.md。

  请为以下排查步骤生成 KQL 查询：

  --- 需要 Kusto 查询的步骤 ---
  {从排查计划中筛选 source=kusto 的步骤}
  --- 结束 ---

  ADX 集群配置：{集群信息}

  完成后，用 SendMessage 将 KQL 查询列表发送给 team-lead。
  """
)
```

kusto-author 完成后：

```
Agent(
  name="kusto-executor",
  team_name="ticket-investigation",
  subagent_type="general-purpose",
  prompt="""
  你是 kusto-executor（KQL 执行者）。请阅读你的 Agent 定义文件 .claude/agents/kusto-executor.md。

  请执行以下 KQL 查询并返回结果：

  --- KQL 查询列表 ---
  {kusto-author 生成的查询}
  --- 结束 ---

  完成后，用 SendMessage 将执行结果发送给 team-lead。
  """
)
```

#### 3b. DevOps 搜索（与 Kusto 并行）

```
Agent(
  name="devops-searcher",
  team_name="ticket-investigation",
  subagent_type="general-purpose",
  prompt="""
  你是 devops-searcher（DevOps 搜索员）。请阅读你的 Agent 定义文件 .claude/agents/devops-searcher.md。

  请执行以下搜索任务：

  --- 需要 DevOps 搜索的步骤 ---
  {从排查计划中筛选 source=devops_* 的步骤}
  --- 结束 ---

  DevOps 配置：{从 config/devops-projects.json 读取}

  完成后，用 SendMessage 将搜索结果发送给 team-lead。
  """
)
```

#### 3c. 文档搜索（与 Kusto 并行）

```
Agent(
  name="doc-searcher",
  team_name="ticket-investigation",
  subagent_type="general-purpose",
  prompt="""
  你是 doc-searcher（文档搜索员）。请阅读你的 Agent 定义文件 .claude/agents/doc-searcher.md。

  请搜索以下相关文档：

  --- 需要文档搜索的步骤 ---
  {从排查计划中筛选 source=docs 的步骤}
  --- 结束 ---

  完成后，用 SendMessage 将搜索结果发送给 team-lead。
  如果发现 Azure 有活跃的服务事件与当前问题相关，立即优先报告。
  """
)
```

---

### Step 4: Phase 4 — 汇总分析

收集所有 Agent 的结果后，team-lead 执行：

1. **综合分析**：将 Kusto 查询结果、DevOps 搜索结果、文档搜索结果关联分析
2. **判断是否需要迭代**：
   - 如果根因已明确 → 生成报告
   - 如果需要深挖 → 回到 Step 2，制定追加排查计划（最多 3 轮迭代）
3. **生成报告**：使用 `templates/report-template.md` 模板，填充排查结果
4. **输出报告**：将完整报告展示给用户

---

### Step 5: 清理

1. 关闭所有 Agent：
   ```
   SendMessage(type="shutdown_request", recipient="issue-analyst")
   SendMessage(type="shutdown_request", recipient="investigation-planner")
   SendMessage(type="shutdown_request", recipient="kusto-author")
   SendMessage(type="shutdown_request", recipient="kusto-executor")
   SendMessage(type="shutdown_request", recipient="devops-searcher")
   SendMessage(type="shutdown_request", recipient="doc-searcher")
   ```

2. 删除团队：
   ```
   TeamDelete()
   ```

---

## team-lead 决策指南

### 何时迭代
- Kusto 查询返回 0 行数据 → 调整时间范围或查询条件，再次查询
- 排查结果互相矛盾 → 追加查询以验证
- 发现新的可疑方向 → 制定补充排查步骤

### 何时结束
- 找到明确根因，且有数据支撑
- 已执行 3 轮迭代但仍无法定位 → 输出当前发现，建议人工介入
- Azure 服务状态显示有活跃事件 → 直接输出事件信息作为根因

### 迭代上限
- 最多 3 轮迭代，避免无限循环
- 每轮迭代都要有新的排查方向，不要重复相同的查询

---

## 配置提示

首次使用前，请修改以下配置文件：
1. `config/adx-clusters.json` — 填入实际的 ADX 集群和表信息
2. `config/devops-projects.json` — 填入 Azure DevOps 组织和项目信息
3. 确保 `az login` 已完成认证
