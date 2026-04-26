# Program Flow

## Demo Timeline Flow

```mermaid
flowchart LR
  T0[0 to 3 s normal flight] --> T1[3 s damage starts]
  T1 --> T2[3 to 4 s damage ramp]
  T2 --> T3[Residual features accumulate]
  T3 --> T4[5 s assessment decision]
  T4 --> T5[Mode command applied]
  T5 --> T6[Trajectory speed altitude assessment export]
```

## Main Model Flow

```mermaid
flowchart TD
  M1[6DOF FixedWing] --> M2[Sensor Output Bus]
  M2 --> M3[Online Damage Identifier]
  M3 --> M4[Decision Logic]
  M4 --> M5[Actuator / Propulsion]
  M5 --> M1
  M3 --> M6[Visualization Interface]
```

## Offline Training vs Online Inference

```mermaid
flowchart LR
  D1[Dataset Generation] --> D2[Feature Builder]
  D2 --> D3[Identifier Training]
  D3 --> D4[Best Model Selection]
  D4 --> O1[Online Inference]
  O1 --> O2[Assessment and Decision]
  O2 --> O3[Demo and closed loop result summaries]
```
