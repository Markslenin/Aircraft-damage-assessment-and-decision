# 受损固定翼飞行器在线损伤识别与任务决策项目

本工程采用 MATLAB Project + Simulink + Aerospace Blockset 组织，面向“受损固定翼飞行器在线损伤识别与任务决策”课题的分阶段原型开发。

当前阶段：

- P1：损伤参数化、剩余可控性评估、规则式决策、批量场景仿真
- P2：残差驱动识别原型、时序数据集、基线识别器、identified/oracle 闭环对比
- P3：统一名义预测、滤波残差、更强特征工程、可插拔识别模型、带置信度的闭环评估

## 目录结构

- `models/`：主模型与子系统
- `scripts/`：初始化、批量场景、识别数据集、评估、benchmark、闭环测试脚本
- `functions/`：损伤解析、名义预测、残差、特征、识别、评估、决策函数
- `data/`：摘要数据集与识别器数据集
- `results/`：仿真、识别评估、闭环评估结果与图表
- `docs/`：项目说明

## 当前项目目标

形成一个可运行的原型系统，完成：

```text
统一名义预测 -> 滤波残差 -> 更强识别器 -> 带置信度的闭环评估
```

并保持 Simulink 主模型可 `update`、可短时仿真、可继续替换为更高保真模块。

## 已实现程度

- P1：完整可运行
- P2：完整打通，但识别精度仍偏原型级
- P3：已建立更真实的残差驱动与更强的评估框架，当前重点是“可信度提升”和“评估质量提升”，不是最终高精度

## 损伤向量定义

`theta_d` 为 12x1 连续损伤向量，每一维取值建议在 `[0,1]`：

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

## P1 核心评估链

- `parse_damage_vector`：损伤语义解析
- `map_damage_to_aero_effects`：损伤到气动/控制效能映射
- `compute_control_authority_metrics`：剩余可控性指标
- `evaluate_trim_feasibility`：规则式可配平性判定
- `decision_manager`：规则式任务决策

### 可控性指标

- `eta_roll`
- `eta_pitch`
- `eta_yaw`
- `eta_total`

```text
eta_total = 0.35 * eta_roll + 0.40 * eta_pitch + 0.25 * eta_yaw
```

### 决策模式

- `NORMAL`
- `STABILIZE`
- `RETURN`
- `DIVERT`
- `EGRESS_PREP`
- `UNRECOVERABLE`

## P2 / P3 识别目标

当前支持两类识别目标：

1. 直接估计 `theta_d_hat`
2. 估计 `eta_hat`

当前默认主任务仍是 `eta_hat` 识别，输出：

- `eta_roll_hat`
- `eta_pitch_hat`
- `eta_yaw_hat`
- `eta_total_hat`

保留 `theta_d_hat` 识别接口作为后续扩展。

入口配置：

- `functions/get_identifier_target_config.m`

配置字段包括：

- `mode`
- `targetNames`
- `featureMode`
- `sequenceLength`
- `residualFilterMode`
- `residualWindowLength`

## P3 名义预测器

P3 引入统一名义模型预测模块：

- `functions/predict_nominal_response.m`

输入：

- `currentState`
- `commandedInput`
- `dt`
- `nominalParams`

输出：

- `predictedVel`
- `predictedAngRate`
- `predictedAttitude`
- `predictedAccel`

当前实现基于简化固定翼模型，是一个工程化名义预测器。

局限：

- 不是严格观测器
- 不是滤波器意义上的最优估计
- 当前更适合做统一残差基准，而不是高精度状态估计

TODO：

- 后续可替换为 EKF / UKF / MHE / 更严格观测器

## P3 残差生成与滤波

残差生成：

- `functions/compute_sensor_residuals.m`

当前残差包括：

- `velResidual`
- `angRateResidual`
- `attitudeResidual`
- `accelResidual`
- `controlTrackingResidual`

残差滤波：

- `functions/filter_residual_sequence.m`

当前支持：

- `moving_average`
- `lowpass_placeholder`

说明：

- `moving_average` 为当前默认模式
- `lowpass_placeholder` 目前仍是工程近似接口

## P3 特征模式

特征工程由：

- `functions/build_identifier_features.m`

当前支持：

- `summary`
- `sequence`
- `summary_plus_residual_energy`
- `summary_plus_cross_channel_stats`
- `hybrid_sequence_summary`

### 各模式含义

- `summary`：基础统计摘要
- `sequence`：原始序列堆叠
- `summary_plus_residual_energy`：摘要 + 残差能量与峰值
- `summary_plus_cross_channel_stats`：摘要 + 残差能量 + 输入/状态相关性摘要
- `hybrid_sequence_summary`：同时输出
  - `summaryFeatures`
  - `sequenceFeatures`

适用场景：

- 线性/浅层模型：优先 `summary` 系列
- 时序模型占位：优先 `hybrid_sequence_summary` 或 `sequence`

## P3 多模型训练框架

训练配置入口：

- `functions/get_identifier_model_config.m`

当前支持模型类型：

- `ridge`
- `shallow_mlp`
- `sequence_mlp_placeholder`
- `ensemble_summary`

训练入口：

- `functions/train_damage_identifier.m`

推理入口：

- `functions/run_damage_identifier.m`

当前支持：

- 训练/验证/测试划分
- 特征归一化
- MAE / RMSE 统计
- sequence 模型占位接口

TODO：

- `sequence_mlp_placeholder` 后续替换为真正的 LSTM / TCN / Transformer 时序识别器

## Confidence / Uncertainty 说明

识别器当前输出：

- `confidence`
- `uncertaintyScore`

当前定义是工程近似，不代表严格概率置信度。

当前近似来源：

- 与训练样本的邻近度
- 模型成员间差异占位
- 特征偏离训练分布程度

用途：

- 低置信度时，`decision_manager` 不直接给出激进的 `RETURN`
- 高不确定性时，决策更偏保守

## Oracle Mode 与 Identified Mode

### Oracle Mode

- 使用真实 `theta_d`
- 直接计算真实 `damageEffects`
- 再进入：
  - `compute_control_authority_metrics`
  - `evaluate_trim_feasibility`
  - `decision_manager`

### Identified Mode

- 从残差与特征生成识别器输入
- 运行识别器得到 `eta_hat`
- 由 `eta_hat` 构造估计的 `ctrlMetrics`
- 再进入：
  - `evaluate_trim_feasibility`
  - `decision_manager`

## 危险决策失配定义

当前定义为以下任一情况：

- `oracle = UNRECOVERABLE / EGRESS_PREP`，但 `identified = RETURN`
- `oracle = DIVERT / STABILIZE`，但 `identified = RETURN` 且 `confidence` 较高

相关评估脚本：

- `scripts/run_identifier_closed_loop_batch.m`
- `scripts/evaluate_decision_consistency.m`

## 数据集说明

### P1 摘要数据集

- `data/damage_dataset.mat`

### P2/P3 识别器数据集

- `data/identifier_dataset.mat`

当前数据集版本：

- `identifier_dataset_v2`

每个样本至少包含：

- `theta_d`
- `eta_target`
- `time`
- `stateHist`
- `inputHist`
- `nominalPredictionHist`
- `residualHist`
- `residualFilteredHist`
- `featureSummary`
- `featureModeReadyData`
- `scenarioInfo`
- `datasetSplitTag`

当前增强内容：

- 更长时间窗
- 多初始状态
- 多控制激励
- 多扰动类型

## 主模型部署接口

主模型 `main_damaged_aircraft.slx` 已包含：

- `Online Damage Identifier`

当前接口形式：

- 输入：
  - 状态摘要
  - 控制输入
  - 残差/特征摘要占位
  - `theta_d`
- 输出：
  - `eta_hat`
  - `confidence`

当前仍属于 prototype deployment：

- 内部仍使用占位推理桥接
- 还没有将训练得到的真实识别器直接部署到 Simulink 在线推理

后续替换路径：

- MATLAB Function block 推理
- From Workspace 驱动
- 导出的浅层网络/查表推理模块

## 建议运行顺序

P3 建议运行顺序：

1. `init_project`
2. `generate_identifier_dataset`
3. `benchmark_identifier_models`
4. `evaluate_identifier`
5. `run_identifier_closed_loop_batch`
6. `evaluate_decision_consistency`
7. 打开 `main_damaged_aircraft.slx` 查看 `Online Damage Identifier` 接口

示例命令：

```matlab
openProject('C:/Users/22149/Desktop/FC')
run('C:/Users/22149/Desktop/FC/scripts/init_project.m')
generate_identifier_dataset
benchmark_identifier_models
evaluate_identifier
run_identifier_closed_loop_batch
evaluate_decision_consistency
open_system('C:/Users/22149/Desktop/FC/models/main_damaged_aircraft.slx')
```

## 当前关键文件

### P3 新增或升级的核心函数

- `functions/predict_nominal_response.m`
- `functions/filter_residual_sequence.m`
- `functions/get_identifier_model_config.m`
- `functions/compute_sensor_residuals.m`
- `functions/build_identifier_features.m`
- `functions/train_damage_identifier.m`
- `functions/run_damage_identifier.m`
- `functions/run_online_assessment_pipeline.m`

### P3 新增脚本

- `scripts/benchmark_identifier_models.m`
- `scripts/evaluate_decision_consistency.m`

### 已有 P1/P2 脚本继续沿用

- `scripts/run_batch_scenarios.m`
- `scripts/generate_damage_dataset.m`
- `scripts/postprocess_results.m`
- `scripts/generate_identifier_dataset.m`
- `scripts/evaluate_identifier.m`
- `scripts/run_identifier_closed_loop_batch.m`

## 后续扩展建议

- 用真实 Simulink 日志替换当前工程近似的时序残差
- 将 `sequence_mlp_placeholder` 替换为真正时序网络
- 将 `Online Damage Identifier` 子系统替换为真实在线推理模块
- 引入更高保真的气动、配平求解和任务级模式机
