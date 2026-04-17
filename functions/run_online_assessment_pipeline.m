function result = run_online_assessment_pipeline(theta_d, identifierModel, identifierConfig, mode)
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

sample = simulate_identifier_timeseries(theta_d, identifierConfig, struct('scenarioType', 'pipeline', 'severity', mean(theta_d)));
flightCondition = build_flight_condition();
flightCondition.damageSeverity = mean(theta_d);

oracle = struct();
oracle.damageParams = sample.damageParams;
oracle.damageEffects = sample.damageEffects;
oracle.ctrlMetrics = sample.ctrlMetrics;
oracle.trimInfo = sample.trimInfo;
oracle.decisionOutput = sample.decisionOutput;

if strcmpi(mode, 'oracle')
    result = struct();
    result.mode = 'oracle';
    result.oracle = oracle;
    result.identified = [];
    result.decisionMatch = true;
    result.controllabilityMatch = true;
    return;
end

if isempty(identifierModel)
    error('Identifier model is required for identified mode.');
end

features = sample.featureSummary;
identifierOutput = run_damage_identifier(identifierModel, features);
identified = struct();
identified.identifierOutput = identifierOutput;

if strcmpi(identifierConfig.mode, 'theta') && isfield(identifierOutput, 'theta_d_hat')
    thetaHat = identifierOutput.theta_d_hat;
    damageParamsHat = parse_damage_vector(thetaHat);
    damageEffectsHat = map_damage_to_aero_effects(damageParamsHat, [], sample.inputHist(1, :).');
    ctrlMetricsHat = compute_control_authority_metrics(damageParamsHat, damageEffectsHat, flightCondition);
else
    damageParamsHat = parse_damage_vector(zeros(12, 1));
    damageEffectsHat = estimate_damage_effects_from_eta_hat(identifierOutput, flightCondition);
    ctrlMetricsHat = ctrl_metrics_from_eta_hat(identifierOutput);
end

trimInfoHat = evaluate_trim_feasibility(damageParamsHat, damageEffectsHat, ctrlMetricsHat, flightCondition);
decisionHat = decision_manager(ctrlMetricsHat, trimInfoHat, flightCondition);

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
end
