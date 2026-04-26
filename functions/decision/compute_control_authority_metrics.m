function ctrlMetrics = compute_control_authority_metrics(damageParams, damageEffects, flightConditionOrState)
%COMPUTE_CONTROL_AUTHORITY_METRICS Approximate residual control authority.
%   eta_roll  : aileron effectiveness minus roll-bias penalty
%   eta_pitch : elevator effectiveness minus pitch-bias penalty
%   eta_yaw   : rudder effectiveness minus yaw-bias penalty
%   eta_total : 0.35*eta_roll + 0.40*eta_pitch + 0.25*eta_yaw

if nargin < 1 || isempty(damageParams)
    damageParams = parse_damage_vector(zeros(12, 1));
end

if nargin < 2 || isempty(damageEffects)
    damageEffects = map_damage_to_aero_effects(damageParams, zeros(12, 1), zeros(4, 1));
end

if nargin < 3 || isempty(flightConditionOrState)
    flightCondition = build_flight_condition();
elseif isstruct(flightConditionOrState)
    flightCondition = flightConditionOrState;
else
    flightCondition = build_flight_condition(flightConditionOrState, zeros(4, 1));
end

Pcfg = get_project_params();
qbar = max(1.0, flightCondition.dynamicPressure_Pa);
S = Pcfg.aircraft.wingArea;
b = Pcfg.aircraft.span;
cbar = Pcfg.aircraft.meanAerodynamicChord;

rollAuthorityNominal = qbar * S * b * abs(Pcfg.aero.Cl_da) * 0.35;
pitchAuthorityNominal = qbar * S * cbar * abs(Pcfg.aero.Cmde) * 0.30;
yawAuthorityNominal = qbar * S * b * max(abs(Pcfg.aero.Cn_dr), 0.06) * 0.30;

rollPenalty = min(1.0, abs(damageEffects.rollMomentBias) / max(rollAuthorityNominal, 1.0));
pitchPenalty = min(1.0, abs(damageEffects.pitchMomentBias) / max(pitchAuthorityNominal, 1.0));
yawPenalty = min(1.0, abs(damageEffects.yawMomentBias) / max(yawAuthorityNominal, 1.0));

etaRoll = clamp(damageEffects.aileronEffScale * (1 - 0.55 * rollPenalty), 0.0, 1.0);
etaPitch = clamp(damageEffects.elevatorEffScale * (1 - 0.60 * pitchPenalty) * (1 - 0.15 * damageParams.tailDamage.horizontal), 0.0, 1.0);
etaYaw = clamp(damageEffects.rudderEffScale * (1 - 0.55 * yawPenalty) * (1 - 0.10 * damageParams.tailDamage.vertical), 0.0, 1.0);

etaTotal = 0.35 * etaRoll + 0.40 * etaPitch + 0.25 * etaYaw;
isControllable = etaTotal >= 0.35 && min([etaRoll, etaPitch, etaYaw]) >= 0.15;

ctrlMetrics = struct();
ctrlMetrics.eta_roll = etaRoll;
ctrlMetrics.eta_pitch = etaPitch;
ctrlMetrics.eta_yaw = etaYaw;
ctrlMetrics.eta_total = clamp(etaTotal, 0.0, 1.0);
ctrlMetrics.is_controllable = isControllable;
ctrlMetrics.weights = struct('roll', 0.35, 'pitch', 0.40, 'yaw', 0.25);
ctrlMetrics.biasPenalty = struct('roll', rollPenalty, 'pitch', pitchPenalty, 'yaw', yawPenalty);
end
