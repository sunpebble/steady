# Steady — 综合慢病记事本 设计文档

日期：2026-07-05 · 状态：已确认 · 工作代号：Steady（中文名后议）

## 定位

sunpebble 家族的慢病伴侣："your health, remembered"。综合记录 + 提醒 +
趋势 + 复诊报告，买断制，无订阅，无服务器。首发市场：欧美英语 + 简体中文
双语（en + zh-Hans，xcstrings）。

## 合规边界（红线）

- 只做记录、提醒、事实性统计、报告导出。
- **不诊断、不给用药/治疗建议、不打健康分。**
- 目标范围（血压/血糖区间）全部由用户自行设定；App 只陈述事实
  （"12 次中 9 次在你设定的范围内"），永不评价（不说"控制良好"）。
- 设置页与 PDF 报告页脚带免责声明。
- 定位于 FDA "general wellness" 豁免区与 App Store 健康类审核安全区。
- HealthKit 数据不用于广告/分析（Apple 硬性要求）。

## 功能范围（一期）

### 记录

- 测量类：血压（收缩/舒张）、血糖（含空腹/餐后情境）、体重、心率、血氧。
  **HealthKit 为唯一真源**：手动录入写回 HealthKit；Omron/Withings/Apple
  Watch 等设备数据经 HealthKit 后台 observer 自动读入并与手动记录去重。
  App 本地（SwiftData）只存 HealthKit 装不下的附注（情境、备注）。
- 症状：自定义标签 + 三档严重度 + 时间戳 + 备注（SwiftData）。
- 用药：药名、剂量、每日时段；服药打卡（taken/skipped）。Apple 自带
  Medications 数据不对第三方开放，故自建，但保持薄：提醒 + 打卡，
  不做药物相互作用等功能。

### 录入流

- 统一 "+" 快速录入面板，按类型定制数字键盘，记住上次值与情境作默认。
- 锁屏/主屏 widget：每类一个，一按直达对应录入。
- Watch App：快速录血压/血糖 + 服药打卡 complication，仅此两件事。

### 提醒

测量提醒 + 服药提醒，纯本地通知（UNUserNotificationCenter）。

### 趋势

Swift Charts，周/月/季视图：均值、范围、达标次数（相对用户自设范围）、
服药依从率。只有事实统计，无洞察无建议。

### 复诊报告（核心付费点）

选日期范围 → 本地生成 PDF：测量表格 + 趋势图 + 服药依从 + 症状时间线，
ImageRenderer 渲染，系统分享面板导出。

## 数据与同步

SwiftData + CloudKit 自动同步（用户自己的 iCloud），零服务器。
测量数值本身依赖 HealthKit 自带的跨设备同步。

## 付费（买断）

- **记录与提醒永久免费**——健康数据不做人质。
- 一次性解锁（$16.99 档）：PDF 报告、超过 7 天的趋势视图、CSV 导出、
  全部 widget。
- 二期家庭共享作为 2.0 付费升级或涨价窗口。

## 工程结构

- 复制 Sleeptab/Simmer 模板：xcodegen `project.yml`，App/ Shared/ Widget/
  Tests/ 四目录，Steady.storekit，release-please。
- iOS 17+，SwiftUI + SwiftData。
- 设计遵循站点仓库 BRAND.md（cream/ink/sun 基础），Steady 个性层：
  方格纸/病历本隐喻。

## 一期不做

饮食记录、AI 功能、外部数据导入、家庭共享（二期，CloudKit sharing，
依然无服务器可买断）、Android、任何需要服务器的东西。

## 成功标准

- 上架美区 + 中区，en/zh-Hans 双语。
- 免费路径：录入一条血压 ≤ 10 秒（含打开 widget）。
- 付费路径：首次生成 PDF 报告即为 aha moment，付费墙设在报告导出处。
