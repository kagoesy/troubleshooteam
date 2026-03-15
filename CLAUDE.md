# Troubleshoot Team — Project Memory

## 项目概述

基于 Claude Code Agent Team 的客户工单排查系统。7 个 AI Agent 协作完成从问题分析到根因定位的全流程，封装为 `/investigate` Skill。

- **GitHub**: https://github.com/kagoesy/troubleshooteam
- **架构**: 扁平星型（team-lead 统一调度，6 个专职 Agent）
- **目标场景**: 客户工单调查（Azure 环境）

## 架构决策

- **扁平星型架构** — 所有 Agent 仅与 team-lead 通信，lead 统一调度（方案 A）。选择原因：工单排查需要多轮迭代，team-lead 统一调度更可控，方便根据中间结果调整排查方向。
- **Agent 定义用 symlink 安装** — `install.sh`/`install.ps1` 将 agents 和 commands symlink 到 `~/.claude/`，git pull 即可更新。Windows 无权限时自动降级为 copy 模式。
- **配置与代码分离** — `config/` 目录存放环境相关配置（ADX 集群、DevOps 项目），更换环境只需改配置。
- **MCP/Skills 预留** — 每个 Agent 定义文件中有注释占位的扩展点，`config/agent-tools.json` 集中管理所有 Agent 的 MCP 和 Skills 开关。

## 7 个 Agent 角色

| Agent | 文件 | 职责 |
|-------|------|------|
| team-lead | （由 /investigate 命令充当） | 调度中心，接收工单、派发任务、汇总结果、生成报告 |
| issue-analyst | `.claude/agents/issue-analyst.md` | 从工单提取结构化信息（实体、时间、错误码、症状） |
| investigation-planner | `.claude/agents/investigation-planner.md` | 制定假设驱动的排查计划，标注并行组和优先级 |
| kusto-author | `.claude/agents/kusto-author.md` | 生成优化的 KQL 查询，提供备选查询 |
| kusto-executor | `.claude/agents/kusto-executor.md` | 通过 az cli/REST API 执行 KQL，格式化结果 |
| devops-searcher | `.claude/agents/devops-searcher.md` | 搜索 Azure DevOps Wiki/代码/Work Items |
| doc-searcher | `.claude/agents/doc-searcher.md` | 搜索 Microsoft 官方文档、Azure 状态、社区知识 |

## 4 阶段排查流程

1. **Phase 1 — 理解问题**: issue-analyst 解析工单 → 结构化摘要
2. **Phase 2 — 制定计划**: investigation-planner 生成排查步骤
3. **Phase 3 — 并行执行**: kusto-author→kusto-executor（串行），devops-searcher 和 doc-searcher（并行）
4. **Phase 4 — 汇总迭代**: team-lead 综合结果，最多 3 轮迭代，输出报告

## 技术环境

| 组件 | 选型 |
|------|------|
| Kusto 查询 | Azure Data Explorer (ADX)，通过 az cli 执行 |
| DevOps 平台 | Azure DevOps（Wiki + Repos + Work Items），通过 az devops CLI / REST API |
| 文档搜索 | WebSearch + WebFetch |
| 认证 | az login（统一） |

## 项目结构

```
.claude/agents/          — 6 个 Agent 定义（.md）
.claude/commands/        — /investigate Skill 入口
config/                  — 环境配置（adx-clusters, devops-projects, agent-tools）
templates/               — 排查报告模板
docs/plans/              — 设计文档和实现计划
install.sh / install.ps1 — 跨平台安装脚本（symlink 到 ~/.claude/）
uninstall.sh / .ps1      — 卸载脚本
```

## 待扩展（MCP/Skills 预留）

所有扩展点在 `config/agent-tools.json` 集中管理，`enabled: false` 待启用：

- issue-analyst: ServiceNow MCP, Jira MCP
- investigation-planner: 知识库 MCP, 排查模板 Skill
- kusto-author: ADX Schema MCP, KQL 模板库 Skill
- kusto-executor: ADX Query MCP
- devops-searcher: Azure DevOps MCP
- doc-searcher: Confluence MCP, SharePoint MCP
