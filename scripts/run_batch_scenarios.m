function summary = run_batch_scenarios()
%RUN_BATCH_SCENARIOS Run a P1 batch of representative damage scenarios.

rootDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(rootDir, 'scripts', 'init_project.m'));
run(fullfile(rootDir, 'scripts', 'generate_project.m'));

modelName = 'main_damaged_aircraft';
load_system(fullfile(rootDir, 'models', [modelName '.slx']));
scenarioDefs = build_default_damage_scenarios();
summary = repmat(empty_summary_entry(), numel(scenarioDefs), 1);

for i = 1:numel(scenarioDefs)
    thetaScenario = scenarioDefs(i).theta_d(:);
    assignin('base', 'theta_d', thetaScenario);

    damageParams = parse_damage_vector(thetaScenario);
    flightCondition = build_flight_condition();
    flightCondition.damageSeverity = damageParams.severity.overall;
    damageEffects = map_damage_to_aero_effects(damageParams, [], evalin('base', 'P.control.trim'));
    ctrlMetrics = compute_control_authority_metrics(damageParams, damageEffects, flightCondition);
    trimInfo = evaluate_trim_feasibility(damageParams, damageEffects, ctrlMetrics, flightCondition);
    decisionOutput = decision_manager(ctrlMetrics, trimInfo, flightCondition);

    simSuccess = false;
    simErrorMessage = "";
    simFinalTime = NaN;

    try
        simOut = sim(modelName, 'StopTime', '0.5');
        simSuccess = true;
        if isprop(simOut, 'tout') || isfield(simOut, 'tout')
            simFinalTime = simOut.tout(end);
        end
    catch simErr
        simErrorMessage = string(simErr.message);
    end

    summary(i).scenarioId = i;
    summary(i).scenarioType = scenarioDefs(i).scenarioType;
    summary(i).severity = scenarioDefs(i).severity;
    summary(i).theta_d = thetaScenario;
    summary(i).damageParams = damageParams;
    summary(i).damageEffects = damageEffects;
    summary(i).ctrlMetrics = ctrlMetrics;
    summary(i).trimInfo = trimInfo;
    summary(i).decisionOutput = decisionOutput;
    summary(i).simSuccess = simSuccess;
    summary(i).simErrorMessage = char(simErrorMessage);
    summary(i).simFinalTime_s = simFinalTime;
end

resultsDir = fullfile(rootDir, 'results');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

summaryTable = struct_array_to_table(summary);
save(fullfile(resultsDir, 'batch_run_summary.mat'), 'summary', 'summaryTable');
writetable(summaryTable, fullfile(resultsDir, 'batch_run_summary.csv'));

fprintf('Batch scenarios complete: %d total, %d success, %d failed.\n', ...
    numel(summary), nnz([summary.simSuccess]), nnz(~[summary.simSuccess]));

assignin('base', 'theta_d', zeros(12, 1));
end

function entry = empty_summary_entry()
entry = struct( ...
    'scenarioId', 0, ...
    'scenarioType', '', ...
    'severity', 0, ...
    'theta_d', zeros(12, 1), ...
    'damageParams', struct(), ...
    'damageEffects', struct(), ...
    'ctrlMetrics', struct(), ...
    'trimInfo', struct(), ...
    'decisionOutput', struct(), ...
    'simSuccess', false, ...
    'simErrorMessage', '', ...
    'simFinalTime_s', NaN);
end

function tbl = struct_array_to_table(summary)
n = numel(summary);

scenarioId = zeros(n, 1);
scenarioType = strings(n, 1);
severity = zeros(n, 1);
etaTotal = zeros(n, 1);
etaRoll = zeros(n, 1);
etaPitch = zeros(n, 1);
etaYaw = zeros(n, 1);
isControllable = false(n, 1);
isTrimmable = false(n, 1);
trimRiskLevel = strings(n, 1);
decisionMode = strings(n, 1);
simSuccess = false(n, 1);
simFinalTime_s = NaN(n, 1);

thetaMat = zeros(n, 12);

for i = 1:n
    scenarioId(i) = summary(i).scenarioId;
    scenarioType(i) = string(summary(i).scenarioType);
    severity(i) = summary(i).severity;
    thetaMat(i, :) = summary(i).theta_d(:).';
    etaRoll(i) = summary(i).ctrlMetrics.eta_roll;
    etaPitch(i) = summary(i).ctrlMetrics.eta_pitch;
    etaYaw(i) = summary(i).ctrlMetrics.eta_yaw;
    etaTotal(i) = summary(i).ctrlMetrics.eta_total;
    isControllable(i) = summary(i).ctrlMetrics.is_controllable;
    isTrimmable(i) = summary(i).trimInfo.is_trimmable;
    trimRiskLevel(i) = string(summary(i).trimInfo.trimRiskLevel);
    decisionMode(i) = string(summary(i).decisionOutput.mode);
    simSuccess(i) = summary(i).simSuccess;
    simFinalTime_s(i) = summary(i).simFinalTime_s;
end

tbl = table(scenarioId, scenarioType, severity, ...
    thetaMat(:, 1), thetaMat(:, 2), thetaMat(:, 3), thetaMat(:, 4), ...
    thetaMat(:, 5), thetaMat(:, 6), thetaMat(:, 7), thetaMat(:, 8), ...
    thetaMat(:, 9), thetaMat(:, 10), thetaMat(:, 11), thetaMat(:, 12), ...
    etaRoll, etaPitch, etaYaw, etaTotal, ...
    isControllable, isTrimmable, trimRiskLevel, decisionMode, simSuccess, simFinalTime_s, ...
    'VariableNames', { ...
        'scenarioId', 'scenarioType', 'severity', ...
        'left_inner_wing', 'left_outer_wing', 'right_inner_wing', 'right_outer_wing', ...
        'left_horizontal_tail', 'right_horizontal_tail', 'vertical_tail', ...
        'left_aileron_eff', 'right_aileron_eff', 'elevator_eff', 'rudder_eff', 'thrust_eff', ...
        'eta_roll', 'eta_pitch', 'eta_yaw', 'eta_total', ...
        'is_controllable', 'is_trimmable', 'trimRiskLevel', 'decisionMode', 'simSuccess', 'simFinalTime_s'});
end
