function damageEffects = map_damage_to_aero_effects(damageParams, currentState, controlInput)
%MAP_DAMAGE_TO_AERO_EFFECTS Engineering mapping from damage to aero effects.
%   damageEffects fields:
%     liftScale, dragScale
%     rollMomentBias, pitchMomentBias, yawMomentBias
%     aileronEffScale, elevatorEffScale, rudderEffScale, thrustEffScale

if nargin < 1 || isempty(damageParams)
    damageParams = parse_damage_vector(zeros(12, 1));
end

if nargin < 2
    currentState = zeros(12, 1);
end

if nargin < 3
    controlInput = zeros(4, 1);
end

flightCondition = build_flight_condition(currentState, controlInput);
Pcfg = evalin('base', 'P');

qbar = flightCondition.dynamicPressure_Pa;
S = Pcfg.aircraft.wingArea;
b = Pcfg.aircraft.span;
cbar = Pcfg.aircraft.meanAerodynamicChord;

leftWing = damageParams.wingDamage.left;
rightWing = damageParams.wingDamage.right;
wingTotal = damageParams.wingDamage.total;
wingAsym = damageParams.wingDamage.asymmetry;
tailH = damageParams.tailDamage.horizontal;
tailHAsym = damageParams.tailDamage.horizontalAsymmetry;
tailV = damageParams.tailDamage.vertical;

aileronLeftScale = clamp(damageParams.controlEff.aileronLeft * (1 - 0.20 * leftWing), 0.05, 1.0);
aileronRightScale = clamp(damageParams.controlEff.aileronRight * (1 - 0.20 * rightWing), 0.05, 1.0);

damageEffects = struct();
damageEffects.liftScale = clamp(1.0 - 0.50 * wingTotal - 0.18 * tailH - 0.08 * tailV, 0.20, 1.0);
damageEffects.dragScale = 1.0 + 0.75 * wingTotal + 0.30 * tailH + 0.18 * tailV;
damageEffects.sideForceCoeffBias = 0.03 * tailV + 0.015 * wingAsym;

damageEffects.rollMomentBias = qbar * S * b * (0.045 * wingAsym);
damageEffects.pitchMomentBias = qbar * S * cbar * (-0.050 * tailH - 0.020 * wingTotal + 0.018 * tailHAsym);
damageEffects.yawMomentBias = qbar * S * b * (0.040 * tailV + 0.020 * wingAsym);

damageEffects.aileronLeftScale = aileronLeftScale;
damageEffects.aileronRightScale = aileronRightScale;
damageEffects.aileronEffScale = clamp(mean([aileronLeftScale, aileronRightScale]), 0.05, 1.0);
damageEffects.elevatorEffScale = clamp(damageParams.controlEff.elevator * (1 - 0.30 * tailH), 0.05, 1.0);
damageEffects.rudderEffScale = clamp(damageParams.controlEff.rudder * (1 - 0.35 * tailV), 0.05, 1.0);
damageEffects.thrustEffScale = clamp(damageParams.controlEff.thrust, 0.05, 1.0);

damageEffects.metadata = struct( ...
    'qbar_Pa', qbar, ...
    'airspeed_mps', flightCondition.airspeed_mps, ...
    'alpha_rad', flightCondition.alpha_rad, ...
    'beta_rad', flightCondition.beta_rad);
end

function y = clamp(x, lo, hi)
y = min(max(x, lo), hi);
end
