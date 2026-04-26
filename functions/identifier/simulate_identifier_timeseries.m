function sample = simulate_identifier_timeseries(theta_d, identifierConfig, scenarioInfo)
%SIMULATE_IDENTIFIER_TIMESERIES Create surrogate histories for identifier work.
%   TODO: Replace surrogate generation with logged plant trajectories and a
%   proper state observer once the online identifier is deployed.

if nargin < 2 || isempty(identifierConfig)
    identifierConfig = get_identifier_target_config();
end
if nargin < 3
    scenarioInfo = struct();
end

Pcfg = get_project_params();
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
if ~isfield(scenarioInfo, 'windLevel_mps') || isempty(scenarioInfo.windLevel_mps)
    scenarioInfo.windLevel_mps = 0.0;
end
if ~isfield(scenarioInfo, 'excitationType') || isempty(scenarioInfo.excitationType)
    scenarioInfo.excitationType = 'step_sine';
end
if ~isfield(scenarioInfo, 'splitTag') || isempty(scenarioInfo.splitTag)
    scenarioInfo.splitTag = 'train';
end
if ~isfield(scenarioInfo, 'damageCategory') || isempty(scenarioInfo.damageCategory)
    scenarioInfo.damageCategory = 'generic';
end
if ~isfield(scenarioInfo, 'damageSeverityLevel') || isempty(scenarioInfo.damageSeverityLevel)
    scenarioInfo.damageSeverityLevel = 'moderate';
end
if ~isfield(scenarioInfo, 'flightConditionTag') || isempty(scenarioInfo.flightConditionTag)
    scenarioInfo.flightConditionTag = 'default';
end
if ~isfield(scenarioInfo, 'datasetVersion') || isempty(scenarioInfo.datasetVersion)
    scenarioInfo.datasetVersion = 'identifier_dataset_v3';
end
if ~isfield(scenarioInfo, 'damageStartTime') || isempty(scenarioInfo.damageStartTime)
    scenarioInfo.damageStartTime = 0.0;
end
if ~isfield(scenarioInfo, 'damageRampDuration') || isempty(scenarioInfo.damageRampDuration)
    scenarioInfo.damageRampDuration = 1.0;
end

dt = identifierConfig.sequenceDt;
t = (0:dt:identifierConfig.historyDuration).';
N = numel(t);

baseState = repmat(scenarioInfo.initialState(:).', N, 1);
uCmdBase = build_command_profile(Pcfg, t, scenarioInfo);
uCmdBase = apply_excitation(uCmdBase, t, scenarioInfo.excitationType);
damageGate = build_damage_gate(t, scenarioInfo.damageStartTime, scenarioInfo.damageRampDuration);

damageEffects = map_damage_to_aero_effects(damageParams, scenarioInfo.initialState, uCmdBase(1, :).');
flightCondition = build_flight_condition(scenarioInfo.initialState, uCmdBase(1, :).');
flightCondition.damageSeverity = scenario_damage_severity(scenarioInfo, damageParams.severity.overall);
ctrlMetrics = compute_control_authority_metrics(damageParams, damageEffects, flightCondition);

nominalState = zeros(N, 12);
nominalAccel = zeros(N, 3);
nominalControl = zeros(N, 4);
measuredState = zeros(N, 12);
residualExcitation = scenarioInfo.disturbanceGain * build_disturbance_profile(t, damageParams, ctrlMetrics);
residualExcitation = residualExcitation .* damageGate;
windExcitation = build_wind_disturbance_profile(t, scenarioInfo.windLevel_mps);

nominalState(1, :) = scenarioInfo.initialState(:).';
measuredState(1, :) = scenarioInfo.initialState(:).';
nominalControl(1, :) = uCmdBase(1, :);

for k = 2:N
    nomPred = predict_nominal_response(nominalState(k-1, :).', uCmdBase(k-1, :).', dt, Pcfg);
    nominalState(k, :) = nomPred.predictedState(:).';
    nominalAccel(k, :) = nomPred.predictedAccel(:).';
    nominalControl(k, :) = uCmdBase(k-1, :);

    measuredState(k, :) = nominalState(k, :) + residualExcitation(k, :) + windExcitation(k, :);
    measuredState(k, 4) = max(12.0, measuredState(k, 4));
end

nominalPredictionHist = struct();
nominalPredictionHist.stateHist = nominalState;
nominalPredictionHist.predictedAccelHist = nominalAccel;
nominalPredictionHist.controlHist = nominalControl;

residualHist = compute_sensor_residuals(measuredState, uCmdBase, nominalPredictionHist, identifierConfig);
residualFilteredHist = filter_residual_sequence(residualHist, identifierConfig);

% Default behaviour is to build only the configured featureMode (cheap online
% path). Dataset-generation scripts opt in via precomputeAllFeatureModes to
% materialize every supported mode for downstream sweeps.
if isfield(identifierConfig, 'precomputeAllFeatureModes') && identifierConfig.precomputeAllFeatureModes
    featureModes = { ...
        'summary', ...
        'summary_plus_residual_energy', ...
        'summary_plus_cross_channel_stats', ...
        'hybrid_sequence_summary', ...
        'sequence', ...
        'normalized_summary', ...
        'residual_coupling_summary', ...
        'hybrid_sequence_summary_v2'};
else
    featureModes = {identifierConfig.featureMode};
end
featureModeReadyData = struct();
featureInfo = struct();
selectedFeature = [];
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
if isempty(selectedFeature)
    [selectedFeature, featureInfo] = build_identifier_features(measuredState, uCmdBase, residualFilteredHist, identifierConfig);
    featureModeReadyData.(identifierConfig.featureMode) = selectedFeature;
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
sample.damageGate = damageGate;
sample.damageCategory = string(scenarioInfo.damageCategory);
sample.damageSeverityLevel = string(scenarioInfo.damageSeverityLevel);
sample.excitationType = string(scenarioInfo.excitationType);
sample.flightConditionTag = string(scenarioInfo.flightConditionTag);
sample.datasetVersion = string(scenarioInfo.datasetVersion);
sample.ctrlMetrics = ctrlMetrics;
sample.trimInfo = trimInfo;
sample.decisionOutput = decisionOutput;
sample.damageParams = damageParams;
sample.damageEffects = damageEffects;
sample.datasetSplitTag = scenarioInfo.splitTag;
end


function uCmd = build_command_profile(Pcfg, t, scenarioInfo)
normalCommand = Pcfg.control.modeCommands.NORMAL(:) + scenarioInfo.commandBias(:);
uCmd = repmat(normalCommand.', numel(t), 1);
if ~isfield(scenarioInfo, 'decisionMode') || isempty(scenarioInfo.decisionMode)
    return;
end
if ~isfield(scenarioInfo, 'decisionTime') || isempty(scenarioInfo.decisionTime)
    return;
end

modeName = upper(char(string(scenarioInfo.decisionMode)));
if ~isfield(Pcfg.control.modeCommands, modeName)
    return;
end
decisionCommand = Pcfg.control.modeCommands.(modeName)(:) + scenarioInfo.commandBias(:);
idx = t >= scenarioInfo.decisionTime;
uCmd(idx, :) = repmat(decisionCommand.', nnz(idx), 1);
end

function damageGate = build_damage_gate(t, damageStartTime, damageRampDuration)
if damageRampDuration <= 0
    damageGate = double(t >= damageStartTime);
    return;
end
damageGate = min(max((t - damageStartTime) ./ damageRampDuration, 0.0), 1.0);
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
    case 'doublet'
        uCmd(:, 1) = uCmd(:, 1) + 0.03 * ((t > 1.0 & t < 1.8) - (t >= 1.8 & t < 2.6));
        uCmd(:, 2) = uCmd(:, 2) + 0.025 * ((t > 3.0 & t < 3.8) - (t >= 3.8 & t < 4.6));
    case 'multisine'
        uCmd(:, 1) = uCmd(:, 1) + 0.015 * sin(0.20 * t) + 0.010 * sin(0.65 * t);
        uCmd(:, 2) = uCmd(:, 2) + 0.020 * sin(0.17 * t + 0.4);
        uCmd(:, 3) = uCmd(:, 3) + 0.015 * sin(0.11 * t);
        uCmd(:, 4) = uCmd(:, 4) + 0.035 * cos(0.09 * t);
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

function windExcitation = build_wind_disturbance_profile(t, windLevel_mps)
windExcitation = zeros(numel(t), 12);
if windLevel_mps <= 0
    return;
end
windExcitation(:, 5) = 0.08 * windLevel_mps * sin(0.12 * t);
windExcitation(:, 6) = 0.06 * windLevel_mps * cos(0.09 * t);
windExcitation(:, 7) = deg2rad(0.10 * windLevel_mps) * sin(0.16 * t);
windExcitation(:, 9) = deg2rad(0.15 * windLevel_mps) * cos(0.21 * t);
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
