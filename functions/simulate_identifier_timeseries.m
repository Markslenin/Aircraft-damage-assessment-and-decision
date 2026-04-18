function sample = simulate_identifier_timeseries(theta_d, identifierConfig, scenarioInfo)
%SIMULATE_IDENTIFIER_TIMESERIES Create P3 surrogate histories for identifier work.
%   TODO: Replace surrogate generation with logged plant trajectories and a
%   proper state observer once the online identifier is deployed.

if nargin < 2 || isempty(identifierConfig)
    identifierConfig = get_identifier_target_config();
end
if nargin < 3
    scenarioInfo = struct();
end

Pcfg = evalin('base', 'P');
damageParams = parse_damage_vector(theta_d);

if ~isfield(scenarioInfo, 'initialState') || isempty(scenarioInfo.initialState)
    scenarioInfo.initialState = [ ...
        Pcfg.initial.pned_m(:); ...
        Pcfg.initial.uvw_mps(:); ...
        Pcfg.initial.euler_rad(:); ...
        Pcfg.initial.pqr_rps(:)];
end
if ~isfield(scenarioInfo, 'commandBias') || isempty(scenarioInfo.commandBias)
    scenarioInfo.commandBias = zeros(4, 1);
end
if ~isfield(scenarioInfo, 'disturbanceGain') || isempty(scenarioInfo.disturbanceGain)
    scenarioInfo.disturbanceGain = 1.0;
end
if ~isfield(scenarioInfo, 'excitationType') || isempty(scenarioInfo.excitationType)
    scenarioInfo.excitationType = 'step_sine';
end
if ~isfield(scenarioInfo, 'splitTag') || isempty(scenarioInfo.splitTag)
    scenarioInfo.splitTag = 'train';
end

dt = identifierConfig.sequenceDt;
t = (0:dt:identifierConfig.historyDuration).';
N = numel(t);

baseState = repmat(scenarioInfo.initialState(:).', N, 1);
uCmdBase = repmat((Pcfg.control.modeCommands.NORMAL(:) + scenarioInfo.commandBias(:)).', N, 1);
uCmdBase = apply_excitation(uCmdBase, t, scenarioInfo.excitationType);

damageEffects = map_damage_to_aero_effects(damageParams, scenarioInfo.initialState, uCmdBase(1, :).');
flightCondition = build_flight_condition(scenarioInfo.initialState, uCmdBase(1, :).');
flightCondition.damageSeverity = damageParams.severity.overall;
ctrlMetrics = compute_control_authority_metrics(damageParams, damageEffects, flightCondition);

nominalState = zeros(N, 12);
nominalAccel = zeros(N, 3);
nominalControl = zeros(N, 4);
measuredState = zeros(N, 12);
residualExcitation = scenarioInfo.disturbanceGain * build_disturbance_profile(t, damageParams, ctrlMetrics);

nominalState(1, :) = scenarioInfo.initialState(:).';
measuredState(1, :) = scenarioInfo.initialState(:).';
nominalControl(1, :) = uCmdBase(1, :);

for k = 2:N
    nomPred = predict_nominal_response(nominalState(k-1, :).', uCmdBase(k-1, :).', dt, Pcfg);
    nominalState(k, :) = nomPred.predictedState(:).';
    nominalAccel(k, :) = nomPred.predictedAccel(:).';
    nominalControl(k, :) = uCmdBase(k-1, :);

    measuredState(k, :) = nominalState(k, :) + residualExcitation(k, :);
    measuredState(k, 4) = max(12.0, measuredState(k, 4));
end

nominalPredictionHist = struct();
nominalPredictionHist.stateHist = nominalState;
nominalPredictionHist.predictedAccelHist = nominalAccel;
nominalPredictionHist.controlHist = nominalControl;

residualHist = compute_sensor_residuals(measuredState, uCmdBase, nominalPredictionHist, identifierConfig);
residualFilteredHist = filter_residual_sequence(residualHist, identifierConfig);

featureModes = { ...
    'summary', ...
    'summary_plus_residual_energy', ...
    'summary_plus_cross_channel_stats', ...
    'hybrid_sequence_summary', ...
    'sequence'};
featureModeReadyData = struct();
featureInfo = struct();
for i = 1:numel(featureModes)
    cfgLocal = identifierConfig;
    cfgLocal.featureMode = featureModes{i};
    [featureData, info] = build_identifier_features(measuredState, uCmdBase, residualFilteredHist, cfgLocal);
    featureModeReadyData.(featureModes{i}) = featureData;
    if strcmpi(featureModes{i}, identifierConfig.featureMode)
        selectedFeature = featureData;
        featureInfo = info;
    end
end

trimInfo = evaluate_trim_feasibility(damageParams, damageEffects, ctrlMetrics, flightCondition);
decisionOutput = decision_manager(ctrlMetrics, trimInfo, flightCondition);

sample = struct();
sample.theta_d = theta_d(:);
sample.eta_target = [ctrlMetrics.eta_roll, ctrlMetrics.eta_pitch, ctrlMetrics.eta_yaw, ctrlMetrics.eta_total];
sample.time = t;
sample.stateHist = measuredState;
sample.inputHist = uCmdBase;
sample.nominalPredictionHist = nominalPredictionHist;
sample.residualHist = residualHist;
sample.residualFilteredHist = residualFilteredHist;
sample.featureSummary = flatten_feature(selectedFeature);
sample.featureModeReadyData = featureModeReadyData;
sample.featureInfo = featureInfo;
sample.scenarioInfo = scenarioInfo;
sample.ctrlMetrics = ctrlMetrics;
sample.trimInfo = trimInfo;
sample.decisionOutput = decisionOutput;
sample.damageParams = damageParams;
sample.damageEffects = damageEffects;
sample.datasetSplitTag = scenarioInfo.splitTag;
end

function uCmd = apply_excitation(uCmd, t, excitationType)
switch lower(excitationType)
    case 'step_sine'
        uCmd(:, 1) = uCmd(:, 1) + 0.03 * sin(0.35 * t);
        uCmd(:, 2) = uCmd(:, 2) + 0.02 * (t > 2.5);
        uCmd(:, 4) = uCmd(:, 4) + 0.05 * sin(0.12 * t);
    case 'chirp_like'
        uCmd(:, 1) = uCmd(:, 1) + 0.02 * sin((0.1 + 0.03 * t) .* t);
        uCmd(:, 3) = uCmd(:, 3) + 0.02 * sin((0.08 + 0.02 * t) .* t);
        uCmd(:, 4) = uCmd(:, 4) + 0.04 * cos(0.15 * t);
    otherwise
        uCmd(:, 1) = uCmd(:, 1) + 0.02 * sin(0.20 * t);
        uCmd(:, 4) = uCmd(:, 4) + 0.03 * sin(0.10 * t);
end
end

function residualExcitation = build_disturbance_profile(t, damageParams, ctrlMetrics)
N = numel(t);
severity = damageParams.severity.overall;
wingAsym = damageParams.wingDamage.asymmetry;

residualExcitation = zeros(N, 12);
residualExcitation(:, 1) = 0.3 * sin(0.10 * t);
residualExcitation(:, 2) = 0.4 * wingAsym * sin(0.18 * t);
residualExcitation(:, 3) = -0.6 * severity * (1 - exp(-0.2 * t));
residualExcitation(:, 4) = -2.5 * (1 - ctrlMetrics.eta_total) * (1 - exp(-0.25 * t));
residualExcitation(:, 5) = 0.8 * wingAsym * (1 - exp(-0.30 * t));
residualExcitation(:, 6) = 1.2 * (1 - ctrlMetrics.eta_pitch) * (1 - exp(-0.30 * t));
residualExcitation(:, 7) = 0.10 * sign_nonzero(wingAsym) * (1 - ctrlMetrics.eta_roll) * sin(0.40 * t);
residualExcitation(:, 8) = 0.08 * (1 - ctrlMetrics.eta_pitch) * (1 - exp(-0.20 * t));
residualExcitation(:, 9) = 0.06 * (1 - ctrlMetrics.eta_yaw) * sin(0.22 * t);
residualExcitation(:, 10) = 0.05 * sign_nonzero(wingAsym) * (1 - ctrlMetrics.eta_roll) * exp(-0.08 * t);
residualExcitation(:, 11) = 0.05 * (1 - ctrlMetrics.eta_pitch) * exp(-0.08 * t);
residualExcitation(:, 12) = 0.05 * (1 - ctrlMetrics.eta_yaw) * exp(-0.08 * t);
end

function y = flatten_feature(featureData)
if isstruct(featureData)
    y = [featureData.summaryFeatures(:); featureData.sequenceFeatures(:)].';
else
    y = featureData(:).';
end
end

function s = sign_nonzero(x)
if x >= 0
    s = 1;
else
    s = -1;
end
end
