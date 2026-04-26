function [deltaF_b_N, deltaM_b_Nm, controlEffectiveness] = damage_injection_interface(x, u, theta_d)
%DAMAGE_INJECTION_INTERFACE Map structured damage into force/moment deltas.
%   Inputs:
%     x        - 12x1 state vector [pn pe pd u v w phi theta psi p q r]
%     u        - 4x1 control vector [de da dr throttle]
%     theta_d  - 12x1 continuous damage vector, each element in [0, 1]
%   Outputs:
%     deltaF_b_N           - body-axis damage-induced force delta [Fx;Fy;Fz]
%     deltaM_b_Nm          - body-axis damage-induced moment delta [L;M;N]
%     controlEffectiveness - [aileronEquivalent; elevator; rudder; thrust]

if nargin < 1 || isempty(x)
    x = zeros(12, 1);
end

if nargin < 2 || isempty(u)
    u = zeros(4, 1);
end

if nargin < 3 || isempty(theta_d)
    theta_d = zeros(12, 1);
end

x = reshape(x, [], 1);
u = reshape(u, [], 1);
theta_d = reshape(theta_d, [], 1);

if numel(theta_d) ~= 12
    error('theta_d must be a 12x1 vector.');
end

damageParams = parse_damage_vector(theta_d);
damageEffects = map_damage_to_aero_effects(damageParams, x, u);
flightCondition = build_flight_condition(x, u);
Pcfg = get_project_params();

qbar = flightCondition.dynamicPressure_Pa;
S = Pcfg.aircraft.wingArea;
b = Pcfg.aircraft.span;
cbar = Pcfg.aircraft.meanAerodynamicChord;
alpha = flightCondition.alpha_rad;

CLref = Pcfg.aero.CL0 + Pcfg.aero.CLalpha * alpha;
CDref = Pcfg.aero.CD0 + Pcfg.aero.CDk * CLref^2;
Lref = qbar * S * CLref;
Dref = qbar * S * CDref;

deltaLift = (damageEffects.liftScale - 1.0) * Lref;
deltaDrag = (damageEffects.dragScale - 1.0) * Dref;
deltaSideForce = qbar * S * damageEffects.sideForceCoeffBias;

deltaFx = -deltaDrag * cos(alpha) + deltaLift * sin(alpha);
deltaFy = deltaSideForce;
deltaFz = -deltaLift * cos(alpha) - deltaDrag * sin(alpha);

deltaF_b_N = [deltaFx; deltaFy; deltaFz];
deltaM_b_Nm = [ ...
    damageEffects.rollMomentBias; ...
    damageEffects.pitchMomentBias; ...
    damageEffects.yawMomentBias];

controlEffectiveness = [ ...
    damageEffects.aileronEffScale; ...
    damageEffects.elevatorEffScale; ...
    damageEffects.rudderEffScale; ...
    damageEffects.thrustEffScale];

% Keep dimensions consistent even if qbar is very small.
if ~isfinite(qbar)
    deltaF_b_N = zeros(3, 1);
    deltaM_b_Nm = zeros(3, 1);
end

% Reserve these references for future higher-fidelity asymmetric load models.
unusedScales = [b; cbar]; %#ok<NASGU>
end
