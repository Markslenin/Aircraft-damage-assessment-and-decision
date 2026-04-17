# 受损固定翼飞行器在线损伤识别与任务决策项目

本工程采用 MATLAB Project + Simulink + Aerospace Blockset 组织，用于“受损固定翼飞行器在线损伤识别与任务决策”课题的原型开发。当前已推进到 P2 阶段，具备：

- P1：统一损伤参数化、损伤到气动/控制效能映射、剩余可控性评估、可配平性判定、规则式任务决策、批量场景仿真、摘要数据集、结果图表输出
- P2：残差驱动的在线损伤识别原型、时序识别数据集、基线识别器训练与评估、identified/oracle 两种评估模式、识别器与 P1 链路闭环打通

## 项目结构

- `models/`：主模型与后续子模型
- `scripts/`：初始化、建模、批量场景、数据集、识别评估、后处理脚本
- `functions/`：损伤映射、残差构造、识别、可控性评估、可配平性判定、决策管理函数
- `data/`：摘要数据集与识别器数据集
- `results/`：批量运行结果、识别器评估结果、图表输出
- `docs/`：项目说明文档

## 损伤向量定义

`theta_d` 为 12x1 连续损伤向量，每一维取值建议在 `[0, 1]`：

| 索引 | 名称 | 含义 |
| --- | --- | --- |
| 1 | `left_inner_wing` | 左内翼结构损伤 |
| 2 | `left_outer_wing` | 左外翼结构损伤 |
| 3 | `right_inner_wing` | 右内翼结构损伤 |
| 4 | `right_outer_wing` | 右外翼结构损伤 |
| 5 | `left_horizontal_tail` | 左平尾损伤 |
| 6 | `right_horizontal_tail` | 右平尾损伤 |
| 7 | `vertical_tail` | 垂尾损伤 |
| 8 | `left_aileron_eff` | 左副翼效能损失 |
| 9 | `right_aileron_eff` | 右副翼效能损失 |
| 10 | `elevator_eff` | 升降舵效能损失 |
| 11 | `rudder_eff` | 方向舵效能损失 |
| 12 | `thrust_eff` | 推力效能损失 |

推荐解释：

- `0.0`：无损伤或无效能损失
- `0.2`：轻度损伤
- `0.5`：中度损伤
- `0.8`：重度损伤
- `1.0`：近似完全失效

## P1 可控性指标与决策模式

### 可控性指标

- `eta_roll`：基于副翼有效性与滚转偏置力矩惩罚
- `eta_pitch`：基于升降舵有效性、平尾损伤和俯仰偏置力矩惩罚
- `eta_yaw`：基于方向舵/垂尾有效性与偏航偏置力矩惩罚
- `eta_total`：综合指标

```text
eta_total = 0.35 * eta_roll + 0.40 * eta_pitch + 0.25 * eta_yaw
```

`is_controllable` 由单轴下限与 `eta_total` 联合判定。该定义用于 P1/P2 阶段规则式决策，不代表严格的线性系统可控性判据。

### 决策模式

- `NORMAL`：近似无损伤或轻微损伤，按常规任务继续
- `STABILIZE`：先稳定姿态与能量状态
- `RETURN`：具备返场/返航能力
- `DIVERT`：转向低风险备降策略
- `EGRESS_PREP`：仅具备短时稳定能力，准备应急退出
- `UNRECOVERABLE`：剩余可控性/可配平性不足

## P2 识别目标定义

P2 支持两类识别目标：

1. 直接估计 12 维损伤向量 `theta_d_hat`
2. 估计剩余控制能力摘要量 `eta_hat`

当前默认主任务采用 `eta_hat` 识别，输出为：

- `eta_roll_hat`
- `eta_pitch_hat`
- `eta_yaw_hat`
- `eta_total_hat`

`theta_d_hat` 识别接口已在配置层保留，用于下一阶段替换。

配置入口：

- `functions/get_identifier_target_config.m`

其中定义：

- `mode`：`'eta'` 或 `'theta'`
- `targetNames`
- `featureMode`
- `sequenceLength`

## 残差特征定义

### 当前残差定义

P2 当前残差由 `compute_sensor_residuals` 构造，输入为：

- `measuredState`
- `commandedInput`
- `nominalPrediction`

输出包括：

- `velResidual`
- `angRateResidual`
- `attitudeResidual`
- `accelResidual`
- `controlTrackingResidual`

### 当前 nominalPrediction 构造方式

当前 `nominalPrediction` 采用工程化近似方式构造：

- 无损伤基准轨迹作为状态预测
- 对应基准控制作为控制预测
- 速度差分近似构造加速度预测

这是一种 P2 原型实现，用于先打通 “残差 -> 特征 -> 识别” 链路。

TODO：

- 后续可替换为更严格的观测器、状态估计器或模型预测器
- 后续可改为直接使用 Simulink 日志的真实 nominal/measured 对照

## 识别特征模式

`build_identifier_features` 当前支持两种模式：

- `summary`
  - 均值
  - 方差
  - 最大绝对值
  - 首末斜率
  - 能量
- `sequence`
  - 原始序列堆叠

当前默认使用 `summary`。

## 时序识别数据集结构

P2 数据集文件：

- `data/identifier_dataset.mat`

结构形式：

- `identifierDataset.config`
- `identifierDataset.samples(i).theta_d`
- `identifierDataset.samples(i).eta_target`
- `identifierDataset.samples(i).time`
- `identifierDataset.samples(i).stateHist`
- `identifierDataset.samples(i).inputHist`
- `identifierDataset.samples(i).residualHist`
- `identifierDataset.samples(i).featureSummary`
- `identifierDataset.samples(i).scenarioInfo`

当前样本量不大，但代码结构已可扩展到更大规模生成。

## 基线识别器说明

P2 当前实现了两个基线模型接口：

1. 岭回归
2. 浅层 MLP 接口

实现文件：

- `functions/train_damage_identifier.m`
- `functions/run_damage_identifier.m`

默认主模型为岭回归。若本机 MATLAB 可用 `fitrnet`，则可训练浅层 MLP；否则自动回退到可运行基线。

## Oracle Mode 与 Identified Mode

### Oracle Mode

- 使用真实 `theta_d`
- 直接计算真实 `damageEffects`
- 再进入：
  - `compute_control_authority_metrics`
  - `evaluate_trim_feasibility`
  - `decision_manager`

### Identified Mode

- 从残差特征构造识别器输入
- 运行基线识别器得到 `eta_hat`
- 由 `eta_hat` 构造 `ctrlMetrics` 估计值
- 再进入：
  - `evaluate_trim_feasibility`
  - `decision_manager`

P2 当前主要用于比较：

- 识别值驱动评估/决策
- 真值损伤驱动评估/决策

相关文件：

- `functions/run_online_assessment_pipeline.m`
- `scripts/run_identifier_closed_loop_batch.m`

## Simulink 接入说明

主模型 `main_damaged_aircraft.slx` 已预留：

- `Online Damage Identifier`

当前接入方式：

- 子系统输入：`sensor_bus`、`theta_d`
- 当前内部输出：基于 `theta_d` 的占位 `eta_hat`

这是一条显式的识别器部署接口，用于保证模型结构完整、命名明确、可继续替换。

TODO：

- 后续替换为真正基于残差摘要或时序特征的在线识别器
- 后续可替换为 MATLAB Function block、From Workspace、或导出的训练模型推理模块

## 建议运行顺序

P2 建议运行顺序：

1. `init_project`
2. `generate_identifier_dataset`
3. `evaluate_identifier`
4. `run_identifier_closed_loop_batch`
5. 打开 `main_damaged_aircraft.slx` 查看接口

示例命令：

```matlab
openProject('C:/Users/22149/Desktop/FC')
run('C:/Users/22149/Desktop/FC/scripts/init_project.m')
generate_identifier_dataset
evaluate_identifier
run_identifier_closed_loop_batch
open_system('C:/Users/22149/Desktop/FC/models/main_damaged_aircraft.slx')
```

## 主要文件说明

### P1 核心文件

- `functions/parse_damage_vector.m`
- `functions/map_damage_to_aero_effects.m`
- `functions/compute_control_authority_metrics.m`
- `functions/evaluate_trim_feasibility.m`
- `functions/decision_manager.m`
- `scripts/run_batch_scenarios.m`
- `scripts/generate_damage_dataset.m`
- `scripts/postprocess_results.m`

### P2 新增文件

- `functions/get_identifier_target_config.m`
- `functions/compute_sensor_residuals.m`
- `functions/build_identifier_features.m`
- `functions/build_default_damage_scenarios.m`
- `functions/simulate_identifier_timeseries.m`
- `functions/train_damage_identifier.m`
- `functions/run_damage_identifier.m`
- `functions/run_online_assessment_pipeline.m`
- `functions/ctrl_metrics_from_eta_hat.m`
- `functions/estimate_damage_effects_from_eta_hat.m`
- `functions/online_identifier_placeholder_vector.m`
- `scripts/generate_identifier_dataset.m`
- `scripts/evaluate_identifier.m`
- `scripts/run_identifier_closed_loop_batch.m`

## 后续扩展建议

- 用真实 Simulink 日志替换当前工程近似的时序残差
- 将 `eta_hat` 基线模型替换为 LSTM / TCN / Transformer 时序识别器
- 扩展 `theta_d_hat` 直接识别路径
- 将 `Online Damage Identifier` 子系统替换为真正在线推理模块
- 引入更高保真的气动、配平与任务级模式机
