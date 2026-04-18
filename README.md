# Damaged Aircraft Online Identification and Decision

面向受损固定翼飞行器的 MATLAB/Simulink 原型工程，目标是把损伤建模、在线识别、可控性评估和任务决策串成一条可运行流程。

当前工程已覆盖三部分能力：

- 损伤参数化与气动/控制效能映射
- 残差驱动的在线损伤识别与指标估计
- 基于识别结果的闭环任务决策评估

## Project Layout

- `models/`: Simulink 主模型
- `functions/`: 损伤解析、残差、特征、识别与决策函数
- `scripts/`: 数据集生成、训练、评估和批处理脚本
- `data/`: 数据集文件
- `results/`: 评估结果与图表
- `docs/`: 更详细的项目说明

## Core Flow

```text
damage vector
  -> nominal prediction
  -> residual generation / filtering
  -> identifier
  -> controllability / trim assessment
  -> decision manager
```

## Main Outputs

- `eta_hat`: 识别得到的可控性指标估计
- `confidence`: 识别可信度近似量
- 决策模式：`NORMAL`、`STABILIZE`、`RETURN`、`DIVERT`、`EGRESS_PREP`、`UNRECOVERABLE`

## Recommended Run Order

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

## Key Scripts

- `scripts/generate_identifier_dataset.m`
- `scripts/benchmark_identifier_models.m`
- `scripts/evaluate_identifier.m`
- `scripts/run_identifier_closed_loop_batch.m`
- `scripts/evaluate_decision_consistency.m`

详细说明见 [docs/README.md](/C:/Users/22149/Desktop/FC/docs/README.md)。
