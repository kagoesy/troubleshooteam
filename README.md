# Troubleshoot Team

基于 Claude Code Agent Team 的客户工单排查系统。7 个 AI Agent 协作完成从问题分析到根因定位的全流程。

## 架构

```
                    ┌─────────────┐
                    │  team-lead  │
                    └──────┬──────┘
          ┌────────┬───────┼───────┬────────┬────────┐
          ▼        ▼       ▼       ▼        ▼        ▼
     issue     invest.  kusto   kusto   devops    doc
     analyst   planner  author  exec.   search   search
```

**Phase 1** 理解问题 → **Phase 2** 制定计划 → **Phase 3** 并行执行 → **Phase 4** 汇总报告

## 快速开始

### 1. 安装

```bash
git clone https://github.com/kagoesy/troubleshooteam.git
cd troubleshooteam
```

**macOS / Linux：**
```bash
bash install.sh
```

**Windows (PowerShell)：**
```powershell
.\install.ps1
```

> Windows 下创建 symlink 需要**管理员权限**或启用**开发者模式**。如果两者都没有，脚本会自动降级为复制模式安装。

安装脚本会将 Agent 定义和 `/investigate` 命令 symlink 到 `~/.claude/`，**安装后在任意目录都可以使用**。

> ⚠️ 安装后请保留克隆的 repo 目录（symlink 指向这里），更新时 `git pull` 即可自动生效。

### 2. 配置

编辑以下配置文件，填入你的实际环境信息：

```bash
# ADX 集群和表结构
~/.claude/troubleshooteam/config/adx-clusters.json

# Azure DevOps 组织和项目
~/.claude/troubleshooteam/config/devops-projects.json
```

### 3. 前置条件

```bash
# Azure CLI 登录（Kusto 查询和 DevOps 搜索需要）
az login

# 可选：配置 DevOps 默认组织
az devops configure --defaults organization=https://dev.azure.com/YOUR_ORG
```

### 4. 使用

在**任意目录**启动 Claude Code，然后运行：

```
/investigate 工单#12345: 用户反馈从 3/10 开始 API 返回 500 错误，
影响 tenant: contoso.com，主要是 /api/v2/users 接口
```

### 更新 & 卸载

```bash
# 更新（symlink 模式下自动生效）
cd troubleshooteam && git pull
```

```bash
# 卸载 (macOS / Linux)
bash uninstall.sh
```

```powershell
# 卸载 (Windows)
.\uninstall.ps1
```

## 项目结构

```
.claude/
├── agents/                    # 6 个 Agent 定义
│   ├── issue-analyst.md       # 问题分析师：提取结构化工单信息
│   ├── investigation-planner.md # 排查规划师：制定排查步骤
│   ├── kusto-author.md        # KQL 专家：生成查询语句
│   ├── kusto-executor.md      # KQL 执行者：执行查询返回结果
│   ├── devops-searcher.md     # DevOps 搜索：Wiki/代码/Work Items
│   └── doc-searcher.md        # 文档搜索：官方文档/社区知识
└── commands/
    └── investigate.md         # /investigate 命令入口

config/                        # 环境配置（需要根据实际填写）
├── adx-clusters.json          # ADX 集群、数据库、表结构
├── devops-projects.json       # Azure DevOps 组织、项目、Wiki
└── agent-tools.json           # MCP/Skills 扩展点配置

templates/
└── report-template.md         # 排查报告模板

docs/plans/                    # 设计文档
├── *-design.md
└── *-implementation-plan.md
```

## 扩展

每个 Agent 预留了 MCP 工具和 Skills 扩展点。接入新工具：

1. 编辑 `config/agent-tools.json`，将对应工具 `enabled` 改为 `true`
2. 取消 Agent 定义文件中对应注释块
3. 填入连接信息

可扩展的工具方向：
- **工单系统 MCP**：ServiceNow / Jira 直接拉取工单
- **ADX Schema MCP**：自动发现表结构
- **Azure DevOps MCP**：封装搜索 API
- **Confluence MCP**：内部知识库搜索
- **KQL 模板库 Skill**：预定义查询模板

## 技术栈

| 组件 | 选型 |
|------|------|
| AI Agent 框架 | Claude Code Agent Team |
| Kusto 查询 | Azure Data Explorer (ADX) |
| DevOps 平台 | Azure DevOps |
| 文档搜索 | WebSearch + WebFetch |
| CLI 工具 | az cli |
