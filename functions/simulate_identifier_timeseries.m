function sample = simulate_identifier_timeseries(theta_d, identifierConfig, scenarioInfo)
%SIMULATE_IDENTIFIER_TIMESERIES Create lightweight state/input/residual histories.
%   TODO: Replace this engineering surrogate with observer-driven residuals
%   and logged plant histories once the identifier is deployed in Simulink.

if nargin < 2 || isempty(identifierConfig)
    identifierConfig = get_identifier_target_config();
end

if nargin < 3
    scenarioInfo = struct();
end

Pcfg = evalin('base', 'P');
damageParams = parse_damage_vector(theta_d);
uCmd = decision_command_vector(theta_d);
flightCondition = build_flight_condition([], uCmd);
flightCondition.damageSeverity = damageParams.severity.overall;
damageEffects = map_damage_to_aero_effects(damageParams, [], uCmd);
ctrlMetrics = compute_control_authority_metrics(damageParams, damageEffects, flightCondition);

dt = identifierConfig.sequenceDt;
t = (0:dt:identifierConfig.historyDuration).';
N = numel(t);

baseState = [ ...
    repmat(Pcfg.initial.pned_m(:).', N, 1), ...
    repmat(Pcfg.initial.uvw_mps(:).', N, 1), ...
    repmat(Pcfg.initial.euler_rad(:).', N, 1), ...
    repmat(Pcfg.initial.pqr_rps(:).', N, 1)];

V0 = norm(Pcfg.initial.uvw_mps);
severity = damageParams.severity.overall;
wingAsym = damageParams.wingDamage.asymmetry;
tailAsym = damageParams.tailDamage.horizontalAsymmetry;

nominalState = baseState;
nominalState(:, 1) = Pcfg.initial.pned_m(1) + V0 * t;
nominalState(:, 2) = 2.0 * sin(0.12 * t);
nominalState(:, 3) = Pcfg.initial.pned_m(3) - 1.0 * sin(0.08 * t);
nominalState(:, 4) = V0 - 0.4 * sin(0.10 * t);
nominalState(:, 5) = 0.15 * sin(0.20 * t);
nominalState(:, 6) = 0.25 * sin(0.15 * t);
nominalState(:, 7) = deg2rad(1.5) * sin(0.22 * t);
nominalState(:, 8) = Pcfg.initial.euler_rad(2) + deg2rad(0.8) * sin(0.16 * t);
nominalState(:, 9) = deg2rad(0.4) * sin(0.08 * t);
nominalState(:, 10) = 0.04 * cos(0.22 * t);
nominalState(:, 11) = 0.03 * sin(0.16 * t);
nominalState(:, 12) = 0.02 * cos(0.10 * t);

measuredState = nominalState;
measuredState(:, 4) = measuredState(:, 4) - 6.0 * (damageEffects.dragScale - 1.0) .* (1 - exp(-0.5 * t)) ...
    - 3.0 * (1 - damageEffects.thrustEffScale);
measuredState(:, 5) = measuredState(:, 5) + 1.8 * wingAsym .* (1 - exp(-0.7 * t));
measuredState(:, 6) = measuredState(:, 6) + 5.0 * (1 - damageEffects.liftScale) .* (1 - exp(-0.6 * t));
measuredState(:, 7) = measuredState(:, 7) + 0.18 * sign_nonzero(wingAsym) * (1 - ctrlMetrics.eta_roll) .* (1 - exp(-0.8 * t));
measuredState(:, 8) = measuredState(:, 8) + 0.16 * (1 - ctrlMetrics.eta_pitch) .* (1 - exp(-0.6 * t)) ...
    + 0.03 * tailAsym * sin(0.4 * t);
measuredState(:, 9) = measuredState(:, 9) + 0.14 * sign_nonzero(damageEffects.yawMomentBias) * (1 - ctrlMetrics.eta_yaw) .* (1 - exp(-0.5 * t));
measuredState(:, 10) = measuredState(:, 10) + 0.12 * sign_nonzero(wingAsym) * (1 - ctrlMetrics.eta_roll) .* exp(-0.1 * t);
measuredState(:, 11) = measuredState(:, 11) + 0.10 * (1 - ctrlMetrics.eta_pitch) .* exp(-0.08 * t);
measuredState(:, 12) = measuredState(:, 12) + 0.11 * (1 - ctrlMetrics.eta_yaw) .* exp(-0.08 * t);

inputHistory = repmat(uCmd(:).', N, 1);
inputHistory(:, 4) = inputHistory(:, 4) + 0.05 * severity * sin(0.12 * t);

nominalPrediction = struct();
nominalPrediction.stateHist = nominalState;
nominalPrediction.controlHist = repmat(Pcfg.control.modeCommands.NORMAL(:).', N, 1);
nominalPrediction.accelHist = estimate_hist_accel(nominalState(:, 4:6), dt);

residualHist = compute_sensor_residuals(measuredState, inputHistory, nominalPrediction);
[featureSummary, featureInfo] = build_identifier_features(measuredState, inputHistory, residualHist, identifierConfig);

sample = struct();
sample.theta_d = theta_d(:);
sample.time = t;
sample.stateHist = measuredState;
sample.inputHist = inputHistory;
sample.nominalPrediction = nominalPrediction;
sample.residualHist = residualHist;
sample.featureSummary = featureSummary;
sample.featureInfo = featureInfo;
sample.scenarioInfo = scenarioInfo;
sample.damageParams = damageParams;
sample.damageEffects = damageEffects;
sample.ctrlMetrics = ctrlMetrics;
sample.trimInfo = evaluate_trim_feasibility(damageParams, damageEffects, ctrlMetrics, flightCondition);
sample.decisionOutput = decision_manager(ctrlMetrics, sample.trimInfo, flightCondition);
sample.eta_target = [ctrlMetrics.eta_roll, ctrlMetrics.eta_pitch, ctrlMetrics.eta_yaw, ctrlMetrics.eta_total];
end

function accel = estimate_hist_accel(uvw, dt)
accel = [zeros(1, 3); diff(uvw, 1, 1) / max(dt, 1.0e-6)];
end

function s = sign_nonzero(x)
if x >= 0
    s = 1;
else
    s = -1;
end
end
