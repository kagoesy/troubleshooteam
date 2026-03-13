# 工单排查报告: {{TICKET_ID}}

> 生成时间: {{GENERATED_AT}}
> 排查团队: ticket-investigation
> 排查轮次: {{ITERATION_COUNT}}

---

## 1. 问题摘要

| 字段 | 内容 |
|------|------|
| **工单号** | {{TICKET_ID}} |
| **报告人** | {{REPORTER}} |
| **时间范围** | {{TIME_START}} — {{TIME_END}} |
| **受影响服务** | {{SERVICE_NAME}} |
| **严重程度** | {{SEVERITY}} |
| **问题类型** | {{PROBLEM_TYPE}} |

**症状描述：**
{{SYMPTOMS}}

**客户影响：**
{{CUSTOMER_IMPACT}}

---

## 2. 排查假设

| 假设 | 可能性 | 验证结果 |
|------|--------|---------|
{{#HYPOTHESES}}
| {{HYPOTHESIS_DESC}} | {{LIKELIHOOD}} | {{VERIFICATION_RESULT}} |
{{/HYPOTHESES}}

---

## 3. 排查过程

{{#STEPS}}
### 步骤 {{STEP_ID}}: {{STEP_DESC}}

- **数据来源**: {{SOURCE}}
- **优先级**: {{PRIORITY}}

**查询/搜索内容：**
```
{{QUERY_OR_SEARCH}}
```

**发现：**
{{FINDINGS}}

**结论：**
{{CONCLUSION}}

---
{{/STEPS}}

## 4. 根因分析

### 确定的根因

{{ROOT_CAUSE}}

### 证据支撑

{{#EVIDENCE}}
- **{{EVIDENCE_SOURCE}}**: {{EVIDENCE_DESC}}
{{/EVIDENCE}}

### 根因链路

```
{{CAUSE_CHAIN}}
```

---

## 5. 影响范围

| 维度 | 数据 |
|------|------|
| **受影响用户数** | {{AFFECTED_USERS}} |
| **受影响请求数** | {{AFFECTED_REQUESTS}} |
| **影响时间段** | {{IMPACT_DURATION}} |
| **影响区域** | {{IMPACT_REGIONS}} |

---

## 6. 建议措施

### 短期（立即行动）

{{#SHORT_TERM_ACTIONS}}
1. {{ACTION}}
{{/SHORT_TERM_ACTIONS}}

### 长期（后续跟进）

{{#LONG_TERM_ACTIONS}}
1. {{ACTION}}
{{/LONG_TERM_ACTIONS}}

---

## 7. 参考资料

{{#REFERENCES}}
- [{{REF_TITLE}}]({{REF_URL}}) — {{REF_NOTE}}
{{/REFERENCES}}

---

## 附录

### A. 执行的 KQL 查询

{{#KQL_QUERIES}}
**{{QUERY_PURPOSE}}** (`{{CLUSTER}}/{{DATABASE}}`)
```kql
{{KQL_STATEMENT}}
```
{{/KQL_QUERIES}}

### B. 搜索关键词

{{SEARCH_KEYWORDS}}

---

_本报告由 ticket-investigation Agent Team 自动生成_
