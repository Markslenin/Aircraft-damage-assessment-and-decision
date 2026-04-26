function damageEffects = estimate_damage_effects_from_eta_hat(identifierOutput, flightCondition)
%ESTIMATE_DAMAGE_EFFECTS_FROM_ETA_HAT Build approximate effects from eta-hat.
%
%   damageEffects = estimate_damage_effects_from_eta_hat(identifierOutput, flightCondition)
%
%   Used in the identified pipeline branch when the model returns eta-hats
%   rather than a full theta_d. Produces a damageEffects struct compatible
%   with what map_damage_to_aero_effects yields, so downstream
%   evaluate_trim_feasibility / decision_manager work uniformly across the
%   theta-mode and eta-mode identifier branches.
%
%   Requires P in the base workspace (loaded by scripts/init_project.m).

if nargin < 2 || isempty(flightCondition)
    flightCondition = build_flight_condition();
end

Pcfg = get_project_params();
qbar = max(1.0, flightCondition.dynamicPressure_Pa);
S = Pcfg.aircraft.wingArea;
b = Pcfg.aircraft.span;
cbar = Pcfg.aircraft.meanAerodynamicChord;

etaRoll = clamp(identifierOutput.eta_roll_hat, 0.0, 1.0);
etaPitch = clamp(identifierOutput.eta_pitch_hat, 0.0, 1.0);
etaYaw = clamp(identifierOutput.eta_yaw_hat, 0.0, 1.0);
etaTotal = clamp(identifierOutput.eta_total_hat, 0.0, 1.0);

damageEffects = struct();
damageEffects.liftScale = clamp(0.55 + 0.45 * etaPitch, 0.2, 1.0);
damageEffects.dragScale = 1.0 + 0.6 * (1 - etaTotal);
damageEffects.rollMomentBias = qbar * S * b * 0.03 * (1 - etaRoll);
damageEffects.pitchMomentBias = qbar * S * cbar * 0.04 * (1 - etaPitch);
damageEffects.yawMomentBias = qbar * S * b * 0.03 * (1 - etaYaw);
damageEffects.sideForceCoeffBias = 0.02 * (1 - etaYaw);
damageEffects.aileronEffScale = etaRoll;
damageEffects.elevatorEffScale = etaPitch;
damageEffects.rudderEffScale = etaYaw;
damageEffects.thrustEffScale = clamp(0.50 + 0.50 * etaTotal, 0.05, 1.0);
end
