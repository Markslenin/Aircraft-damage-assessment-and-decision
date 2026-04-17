# 受损固定翼飞行器在线损伤识别与任务决策项目

本工程采用 MATLAB Project + Simulink + Aerospace Blockset 组织，目标是为“受损固定翼飞行器在线损伤识别与任务决策”课题提供一个清晰、可扩展的首版骨架。

## 目录结构

- `models/`：主模型与后续子模型。
- `scripts/`：项目初始化、建模与批处理脚本。
- `functions/`：算法函数与接口函数。
- `data/`：参数、试验数据与场景数据。
- `results/`：仿真输出与分析结果。
- `docs/`：项目说明文档。

## 启动步骤

1. 在 MATLAB 中打开工程根目录下的 Project 文件。
2. 运行 `scripts/init_project.m`，加载基础参数到 Base Workspace。
3. 打开 `models/main_damaged_aircraft.slx`。
4. 从主模型开始补充气动、控制律、诊断与任务决策细节。

## 当前首版框架

- 6DOF 刚体动力学：优先使用 Aerospace Blockset `6DoF (Euler Angles)`。
- 环境模块：使用 `ISA Atmosphere Model`、`WGS84 Gravity Model` 和风场占位。
- 执行机构与推进：保留占位接口，便于后续替换为真实舵机/发动机模型。
- 执行机构与推进：当前已接入一个简化固定翼力/矩原型模型，输入为 `x/u_cmd/eta_ctrl`，输出为体轴合力与力矩。
- 损伤注入：当前已接入 `x/u/theta_d -> deltaF/deltaM/controlEffectiveness` 实函数接口。
- 传感器与输出总线：保留统一汇总出口。
- 决策逻辑：保留在线识别与任务重规划入口。

## 后续扩展建议

- 在 `functions/` 中补充气动/损伤辨识/容错控制函数。
- 在 `models/` 中拆分环境、执行机构、传感器和决策子系统为可复用引用模型。
- 在 `data/` 中加入机型参数、风场场景和任务航迹。
- 在 `results/` 中规范保存 Monte Carlo、损伤工况和任务评估结果。
