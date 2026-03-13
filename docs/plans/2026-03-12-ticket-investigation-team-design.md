# 客户工单排查 Agent Team 设计文档

> 日期: 2026-03-12
> 状态: 已确认，开始实现
> 架构: 扁平星型（方案 A）

---

## 1. 概述

构建一个基于 Claude Code Agent Team 的客户工单排查系统，由 7 个 Agent 协作完成从问题分析到根因定位的全流程，最终封装为可复用的 Skill（`/investigate`）。

### 技术环境

| 组件 | 选型 |
|------|------|
| Kusto 查询 | Azure Data Explorer (ADX) |
| DevOps 平台 | Azure DevOps（Wiki + Repos + Work Items） |
| 文档搜索 | WebSearch + WebFetch |
| 执行环境 | Claude Code with Bash, az cli |

---

## 2. 架构总览

```
╔══════════════════════════════════════════════════════════════════════╗
║                     TICKET INVESTIGATION TEAM                       ║
║                                                                      ║
║                        ┌─────────────┐                               ║
║                        │  team-lead  │                               ║
║                        │ (调度中心)   │                               ║
║                        └──────┬──────┘                               ║
║              ┌────────┬───────┼───────┬────────┬────────┐           ║
║              ▼        ▼       ▼       ▼        ▼        ▼           ║
║         ┌────────┐┌───────┐┌──────┐┌──────┐┌───────┐┌───────┐     ║
║         │ issue  ││invest.││kusto ││kusto ││devops ││  doc  │     ║
║         │analyst ││planner││author││exec. ││search ││search │     ║
║         └────────┘└───────┘└──────┘└──────┘└───────┘└───────┘     ║
║                                                                      ║
║  Phase 1: 理解    Phase 2: 规划   Phase 3: 执行与搜集   Phase 4: 汇总 ║
╚══════════════════════════════════════════════════════════════════════╝
```

**通信模型:** 所有 Agent 仅与 team-lead 通信，team-lead 统一调度。

---

## 3. 排查流程（4 阶段）

### Phase 1 — 理解问题

```
team-lead → issue-analyst: "分析这个工单"
issue-analyst → team-lead: 返回结构化问题摘要
```

### Phase 2 — 制定排查计划

```
team-lead → investigation-planner: "基于问题摘要，制定排查步骤"
planner → team-lead: 返回排查计划（含所需数据、查询方向、文档关键词）
```

### Phase 3 — 并行执行（核心并行阶段）

```
team-lead 同时派发任务给：
  → kusto-author: "生成这些 KQL 查询"
  → devops-searcher: "搜索相关 wiki 和代码"
  → doc-searcher: "搜索官方文档"

kusto-author 完成后：
  team-lead → kusto-executor: "执行这些 KQL"

所有结果汇总到 team-lead
```

### Phase 4 — 分析与迭代

```
team-lead 综合所有结果，判断：
  → 根因已定位 → 生成报告
  → 需要深挖 → 回到 Phase 2/3 再次迭代
```

---

## 4. Agent 详细设计

### 4.1 team-lead（调度中心）

| 属性 | 说明 |
|------|------|
| **角色** | 团队指挥官，负责调度所有 agent、汇总结果、做出决策 |
| **agent 类型** | `general-purpose` |
| **核心职责** | ① 接收用户输入的工单 ② 按阶段派发任务 ③ 汇总中间结果 ④ 决定是否需要迭代 ⑤ 生成最终排查报告 |
| **决策逻辑** | 根据返回结果判断：信息是否充足、是否需要追加查询、根因是否明确 |
| **输出** | 结构化排查报告 |
| **MCP 工具** | _预留：后续可接入告警系统 MCP、工单系统 MCP_ |
| **Skills** | _预留：后续可接入报告生成 Skill_ |

### 4.2 issue-analyst（问题分析师）

| 属性 | 说明 |
|------|------|
| **角色** | 从工单/用户描述中提取结构化信息 |
| **agent 类型** | `general-purpose` |
| **核心职责** | ① 解析工单描述 ② 提取关键实体（用户ID、时间范围、服务名、错误码等） ③ 识别问题类型 ④ 获取当前服务状态 |
| **输入** | 原始工单文本、用户补充信息 |
| **输出格式** | 结构化摘要（见下方 Schema） |
| **MCP 工具** | _预留：工单系统 MCP（ServiceNow / Jira / ADO Work Items）_ |
| **Skills** | _预留_ |

**输出 Schema：**

```json
{
  "problem_summary": "string - 一句话问题概述",
  "affected_entities": {
    "tenant_id": "string?",
    "user_id": "string?",
    "subscription_id": "string?",
    "resource_id": "string?"
  },
  "time_range": {
    "start": "ISO8601",
    "end": "ISO8601"
  },
  "error_codes": ["string"],
  "service_name": "string",
  "api_endpoints": ["string"],
  "severity": "P1 | P2 | P3 | P4",
  "symptoms": ["string - 症状列表"],
  "customer_impact": "string - 客户影响描述"
}
```

### 4.3 investigation-planner（排查规划师）

| 属性 | 说明 |
|------|------|
| **角色** | 根据问题摘要制定排查计划 |
| **agent 类型** | `general-purpose` |
| **核心职责** | ① 制定排查步骤清单 ② 明确每步需要的数据 ③ 指定数据获取方式 ④ 设定优先级 |
| **输入** | issue-analyst 的结构化摘要 |
| **输出格式** | 排查计划（见下方 Schema） |
| **MCP 工具** | _预留：知识库 MCP（已知问题库、排查手册）_ |
| **Skills** | _预留_ |

**输出 Schema：**

```json
{
  "investigation_plan": {
    "hypothesis": "string - 初步假设",
    "steps": [
      {
        "id": 1,
        "description": "string - 排查步骤描述",
        "data_needed": "string - 需要的数据",
        "source": "kusto | devops_wiki | devops_code | docs",
        "priority": "high | medium | low",
        "kusto_hints": "string? - KQL 编写提示（表名、筛选条件等）",
        "search_keywords": ["string? - 搜索关键词"],
        "depends_on": [0]
      }
    ]
  }
}
```

### 4.4 kusto-author（KQL 编写专家）

| 属性 | 说明 |
|------|------|
| **角色** | 专门生成 KQL 查询语句 |
| **agent 类型** | `general-purpose` |
| **核心职责** | ① 根据排查需求生成 KQL ② 了解 ADX 集群表结构 ③ 优化查询性能 ④ 提供备选查询 |
| **输入** | 排查计划中 source=kusto 的步骤 |
| **输出格式** | KQL 查询列表（见下方 Schema） |
| **领域知识** | ADX 集群地址、数据库名、常用表和列、常见查询模板 |
| **MCP 工具** | _预留：ADX Schema MCP（自动发现表结构）_ |
| **Skills** | _预留：KQL 模板库 Skill_ |

**输出 Schema：**

```json
{
  "queries": [
    {
      "id": "q1",
      "step_id": 1,
      "purpose": "string - 这个查询要回答什么问题",
      "cluster": "https://xxx.kusto.windows.net",
      "database": "string",
      "kql": "string - KQL 语句",
      "expected_columns": ["string"],
      "fallback_kql": "string? - 如果主查询失败的备选"
    }
  ]
}
```

### 4.5 kusto-executor（KQL 执行者）

| 属性 | 说明 |
|------|------|
| **角色** | 执行 KQL 查询并返回结果 |
| **agent 类型** | `general-purpose`（需要 Bash） |
| **核心职责** | ① 通过 az cli 或 REST API 执行 KQL ② 处理超时/错误 ③ 格式化结果 ④ 初步数据摘要 |
| **输入** | kusto-author 生成的查询列表 |
| **输出格式** | 查询结果（见下方 Schema） |
| **工具依赖** | `az kusto query` / `curl` / `jq` |
| **MCP 工具** | _预留：ADX Query MCP（封装认证和查询执行）_ |
| **Skills** | _预留_ |

**输出 Schema：**

```json
{
  "results": [
    {
      "query_id": "q1",
      "status": "success | error | timeout",
      "row_count": 0,
      "execution_time_ms": 0,
      "summary": "string - 结果摘要",
      "key_findings": ["string - 关键发现"],
      "data_sample": "string - 前 10 行数据（表格格式）",
      "error_message": "string? - 如果失败"
    }
  ]
}
```

### 4.6 devops-searcher（DevOps 搜索员）

| 属性 | 说明 |
|------|------|
| **角色** | 搜索 Azure DevOps Wiki 和代码仓库 |
| **agent 类型** | `general-purpose`（需要 Bash） |
| **核心职责** | ① 搜索 Wiki（排查手册、已知问题、架构文档） ② 搜索代码（错误处理逻辑、配置项） ③ 搜索 Work Items（相关历史 Bug） |
| **输入** | 排查计划中 source=devops_* 的步骤 |
| **输出格式** | 搜索结果（见下方 Schema） |
| **工具依赖** | `az devops` CLI / Azure DevOps REST API |
| **MCP 工具** | _预留：Azure DevOps MCP（封装搜索 API）_ |
| **Skills** | _预留_ |

**输出 Schema：**

```json
{
  "results": [
    {
      "step_id": 1,
      "source_type": "wiki | code | workitem",
      "title": "string",
      "url": "string",
      "relevant_snippet": "string - 相关片段（最多 500 字）",
      "relevance": "high | medium | low",
      "context": "string - 为什么这个结果相关"
    }
  ]
}
```

### 4.7 doc-searcher（文档搜索员）

| 属性 | 说明 |
|------|------|
| **角色** | 搜索官方文档和外部知识库 |
| **agent 类型** | `general-purpose`（需要 WebSearch/WebFetch） |
| **核心职责** | ① 搜索 Microsoft 官方文档 ② 搜索 Azure 服务状态和已知问题 ③ 查找 Stack Overflow / GitHub Issues |
| **输入** | 排查计划中 source=docs 的步骤 |
| **输出格式** | 搜索结果（见下方 Schema） |
| **工具依赖** | `WebSearch` / `WebFetch` |
| **MCP 工具** | _预留：Confluence MCP、知识库 MCP_ |
| **Skills** | _预留_ |

**输出 Schema：**

```json
{
  "findings": [
    {
      "step_id": 1,
      "source": "microsoft_docs | azure_status | stackoverflow | github",
      "title": "string",
      "url": "string",
      "key_insight": "string - 核心发现",
      "applies_to_our_case": true,
      "reasoning": "string - 为什么适用/不适用"
    }
  ]
}
```

---

## 5. 共享任务列表设计

team-lead 通过 TaskList 统一管理，典型任务依赖关系：

```
T1: 分析工单                    → owner: issue-analyst
T2: 制定排查计划                 → owner: investigation-planner  (blockedBy: T1)
T3: 生成 KQL 查询               → owner: kusto-author           (blockedBy: T2)
T4: 搜索 DevOps                → owner: devops-searcher        (blockedBy: T2)
T5: 搜索官方文档                 → owner: doc-searcher           (blockedBy: T2)
T6: 执行 KQL                   → owner: kusto-executor         (blockedBy: T3)
T7: 汇总分析                    → owner: team-lead              (blockedBy: T4, T5, T6)
T8: [可选] 追加排查 (迭代)       → blockedBy: T7
```

---

## 6. 最终输出 — 排查报告模板

```markdown
# 工单排查报告: [工单号]

## 问题摘要
- **报告人**: ...
- **时间范围**: ...
- **受影响服务**: ...
- **症状描述**: ...

## 排查过程
### 步骤 1: [描述]
- **数据来源**: Kusto / DevOps / Docs
- **查询/搜索**: [具体内容]
- **发现**: [结果]

### 步骤 2: ...

## 根因分析
[根因描述，引用具体数据支撑]

## 影响范围
[受影响的用户数/请求数/时间段]

## 建议措施
1. **短期**: ...
2. **长期**: ...

## 参考资料
- [链接1]: 相关 Wiki 页面
- [链接2]: 官方文档
```

---

## 7. 扩展点（MCP / Skills 预留）

以下是每个 Agent 未来可扩展的 MCP 工具和 Skills，当前不实现，但在 Agent 定义中预留配置位置：

| Agent | 预留 MCP | 预留 Skills |
|-------|---------|------------|
| team-lead | 告警系统 MCP、工单系统 MCP | 报告生成 Skill |
| issue-analyst | ServiceNow MCP、Jira MCP | 工单解析 Skill |
| investigation-planner | 知识库 MCP（已知问题库） | 排查模板 Skill |
| kusto-author | ADX Schema MCP | KQL 模板库 Skill |
| kusto-executor | ADX Query MCP | - |
| devops-searcher | Azure DevOps MCP | - |
| doc-searcher | Confluence MCP | - |

---

## 8. Skill 封装设计

最终封装为 `/investigate` 命令：

```
/investigate 工单#12345: 用户反馈从 3/10 开始 API 返回 500 错误，
影响 tenant: contoso.com，主要是 /api/v2/users 接口
```

Skill 入口自动：
1. 创建 Team（`ticket-investigation`）
2. 启动 6 个专职 Agent
3. Phase 1-4 自动流转
4. 输出排查报告
5. 关闭 Team、清理资源
