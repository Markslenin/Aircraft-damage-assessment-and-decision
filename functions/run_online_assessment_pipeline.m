function result = run_online_assessment_pipeline(theta_d, identifierModel, identifierConfig, mode, scenarioInfo)
%RUN_ONLINE_ASSESSMENT_PIPELINE Run oracle or identified assessment chain.

if nargin < 2
    identifierModel = [];
end
if nargin < 3 || isempty(identifierConfig)
    identifierConfig = get_identifier_target_config();
end
if nargin < 4 || isempty(mode)
    mode = 'oracle';
end
if nargin < 5
    scenarioInfo = struct('scenarioType', 'pipeline', 'severity', mean(theta_d), 'splitTag', 'test');
end

sample = simulate_identifier_timeseries(theta_d, identifierConfig, scenarioInfo);
Pcfg = evalin('base', 'P');
flightCondition = build_flight_condition(sample.stateHist(1, :).', sample.inputHist(1, :).');
flightCondition.damageSeverity = mean(theta_d);
flightCondition.decisionConfig = Pcfg.decision;

oracle = struct();
oracle.damageParams = sample.damageParams;
oracle.damageEffects = sample.damageEffects;
oracle.ctrlMetrics = sample.ctrlMetrics;
oracle.trimInfo = sample.trimInfo;
oracle.decisionOutput = sample.decisionOutput;

if strcmpi(mode, 'oracle')
    result = struct('mode', 'oracle', 'oracle', oracle, 'identified', [], ...
        'decisionMatch', true, 'controllabilityMatch', true, 'trimMatch', true);
    return;
end

if isempty(identifierModel)
    error('Identifier model is required for identified mode.');
end

cfgForModel = identifierModel.modelConfig.identifierTargetConfig;
if isfield(sample.featureModeReadyData, cfgForModel.featureMode)
    features = sample.featureModeReadyData.(cfgForModel.featureMode);
else
    [features, ~] = build_identifier_features(sample.stateHist, sample.inputHist, sample.residualFilteredHist, cfgForModel);
end

identifierOutput = run_damage_identifier(identifierModel, features);
identifiedFlightCondition = flightCondition;
identifiedFlightCondition.identifierConfidence = identifierOutput.confidence;
identifiedFlightCondition.identifierUncertainty = identifierOutput.uncertaintyScore;
identifiedFlightCondition.etaHistory = build_eta_history(identifierOutput);

identified = struct();
identified.identifierOutput = identifierOutput;

if strcmpi(cfgForModel.mode, 'theta') && isfield(identifierOutput, 'theta_d_hat')
    thetaHat = identifierOutput.theta_d_hat;
    damageParamsHat = parse_damage_vector(thetaHat);
    damageEffectsHat = map_damage_to_aero_effects(damageParamsHat, sample.stateHist(end, :).', sample.inputHist(end, :).');
    ctrlMetricsHat = compute_control_authority_metrics(damageParamsHat, damageEffectsHat, identifiedFlightCondition);
else
    damageParamsHat = parse_damage_vector(zeros(12, 1));
    damageEffectsHat = estimate_damage_effects_from_eta_hat(identifierOutput, identifiedFlightCondition);
    ctrlMetricsHat = ctrl_metrics_from_eta_hat(identifierOutput);
end

trimInfoHat = evaluate_trim_feasibility(damageParamsHat, damageEffectsHat, ctrlMetricsHat, identifiedFlightCondition);
if identifierOutput.uncertaintyScore > Pcfg.decision.uncertaintyHigh && strcmp(trimInfoHat.trimRiskLevel, 'LOW')
    trimInfoHat.trimRiskLevel = 'MEDIUM';
end

identifiedFlightCondition.previousDecisionMode = sample.decisionOutput.mode;
identifiedFlightCondition.previousModeDuration = Pcfg.decision.minModeDuration - 1;
decisionHat = decision_manager(ctrlMetricsHat, trimInfoHat, identifiedFlightCondition);

identified.damageParams = damageParamsHat;
identified.damageEffects = damageEffectsHat;
identified.ctrlMetrics = ctrlMetricsHat;
identified.trimInfo = trimInfoHat;
identified.decisionOutput = decisionHat;

result = struct();
result.mode = 'identified';
result.oracle = oracle;
result.identified = identified;
result.decisionMatch = strcmpi(oracle.decisionOutput.mode, decisionHat.mode);
result.controllabilityMatch = oracle.ctrlMetrics.is_controllable == ctrlMetricsHat.is_controllable;
result.trimMatch = strcmpi(oracle.trimInfo.trimRiskLevel, trimInfoHat.trimRiskLevel) && ...
    oracle.trimInfo.is_trimmable == trimInfoHat.is_trimmable;
end

function etaHistory = build_eta_history(identifierOutput)
neighbor = identifierOutput.predictionMeta.neighborMean(:).';
current = [identifierOutput.eta_roll_hat, identifierOutput.eta_pitch_hat, identifierOutput.eta_yaw_hat, identifierOutput.eta_total_hat];
etaHistory = [neighbor; current];
end
