# `-seedDemo` 审核演示数据 — Design

> 增量于 [2026-07-05-steady-design.md](./2026-07-05-steady-design.md)。实现 RELEASING.md 承诺的 `-seedDemo` 启动参数。

## Goal

`-seedDemo` 启动参数让模拟器/TestFlight 包瞬间填满演示数据，供审核演示与截图。所有界面（Timeline / Trends / Meds / Settings / Report）立即呈现非空、有意义的状态。

## Context

健康类 App 提审时，审核员（与开发者截图）需要看到有数据的界面——空状态无法体现功能。当前 App 只有空状态引导，无法演示。`RELEASING.md` 末尾已承诺此参数，但代码缺失（`ProStore` 仅有 `-pro`）。

## 核心决策：全内存隔离

检测到 `-seedDemo` 时，App 切换到**内存版**数据栈，完全不碰真实 HealthKit / CloudKit：

- SwiftData 改用 `SteadyModels.testContainer()`（内存、不连 CloudKit）→ 演示的用药/症状不会同步到审核员的 iCloud。
- `HealthStore.readings` 直接预填假 `Reading` 对象，**不写 HealthKit** → 审核员的健康数据零污染。
- 重启 App（不带参数）即回到真实数据栈，演示数据不残留。

代价：演示数据不持久、HealthKit observer 不参与。这对一次性演示场景完全可接受，换来零污染与实现最简。

**不包 `#if DEBUG`**：与 `-pro`（绕过付费，Debug 限制合理）不同，`-seedDemo` 只播种数据、不绕过付费，且审核截图常在 Release/TestFlight 包做。放开配置；正常用户不传参则零影响。

## 落点

| 文件 | 改动 |
|---|---|
| `App/DemoData.swift`（新） | `enum DemoData { static func seed(into health: HealthStore, ctx: ModelContext) }` —— 一次性生成全部演示数据 |
| `App/HealthStore.swift`（改） | 加 `var isDemo = false`；`requestAuthorization()` 在 `isDemo` 时跳过 HK 查询、置 `authorized = true`；`refresh()` 在 `isDemo` 时直接 return（避免覆盖假数据） |
| `App/SteadyApp.swift`（改） | 启动检测 `-seedDemo` → 选 `testContainer` + `health.isDemo = true` + `DemoData.seed(...)` |

## 演示数据内容

覆盖全部界面，数值为真实慢病量级、事实性（无评价词）：

**测量**（5 类 × 最近 90 天，每类 20-40 点，足够 Trends 90D 画图与 Report 分节）：
- 血压 120-145 / 78-92 mmHg（部分越界，使 "In your range" 非满分）
- 血糖 90-140 mg/dL（部分带 `.fasting` / `.afterMeal` mealtime）
- 体重 68-72 kg
- 心率 62-78 bpm
- 血氧 95-98 %

**用药**（2 个，今日部分打卡）：
- Metformin 500mg — 08:00 / 20:00
- Lisinopril 10mg — 08:00

→ Meds 今日清单 + Trends 依从率有数。

**症状**（3-4 条，不同严重度）：头痛 / 乏力 / 头晕等 → Timeline 症状行。

**目标范围**（预设）：血压、血糖、体重 → Trends / Report 显示 "In your range"。

## 约束

- 全内存隔离：零污染、重启即清。
- 不做"清除演示数据"入口（YAGNI：重启即清）。
- 不生成假内购交易——Pro 状态另由 `-pro` 参数覆盖；两者可叠加。
- 合规红线不变：纯事实数值，文案无 good/bad/healthy/良好/正常 等评价词。

## 测试策略

`DemoData.seed` 的纯逻辑可单测（不依赖 HK / 不依赖真实 ModelContainer 持久化）：

- 播种后 `health.readings` 覆盖全部 5 个 `Reading.Kind`
- 覆盖最近 90 天窗口（最早点 ≥ 90 天前）
- SwiftData 中 Medication ≥ 1、含今日 MedLog 打卡
- 症状 ≥ 1 条
- 目标范围已写入（`SettingsStore.targetRange(for: .bloodPressure)` 非 nil）

用 `SteadyModels.testContainer()` 注入，断言上述不变量。
