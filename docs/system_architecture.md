# System Architecture

## Current Block Diagram

```mermaid
flowchart LR
  subgraph OFF[Offline training and model selection]
    A1[Scenario generation] --> A2[Nominal predictor]
    A2 --> A3[Residual filtering]
    A3 --> A4[Feature builder]
    A4 --> A5[Identifier training]
    A5 --> A6[Hyperparameter sweep]
    A6 --> A7[Best identifier model]
  end
  subgraph ON[Timeline aware online assessment]
    B1[Normal flight segment] --> B2[Damage gate and ramp]
    B2 --> B3[Damaged trajectory and sensor residuals]
    B3 --> B4[Filtered residual features]
    B4 --> B5[Damage eta identifier]
    B5 --> B6[Control authority metrics]
    B6 --> B7[Trim feasibility]
    B7 --> B8[Decision manager]
    B8 --> B9[Mode command profile]
    B9 --> B10[Trajectory and assessment figures]
  end
  A7 --> B5
  B8 --> C1[Identified vs oracle comparison]
  B6 --> C1
  C1 --> C2[Closed loop and demo summaries]
```

The current demo chain is explicitly staged as normal flight, damage injection, identification and assessment, and decision-command execution. Offline training remains separated from the online assessment backbone so the identifier model can evolve without changing the control-authority, trim, and decision interfaces.

## Primary Runtime Signals

```mermaid
flowchart TD
  S1[theta_d and scenario metadata] --> S2[Damage effects]
  S2 --> S3[State and input history]
  S3 --> S4[Residual history]
  S4 --> S5[Feature vector]
  S5 --> S6[eta_hat confidence uncertainty]
  S6 --> S7[eta_roll eta_pitch eta_yaw eta_total]
  S7 --> S8[Trim risk and decision mode]
  S8 --> S9[Mode trace and exported figures]
```
