function demoOutputs = run_demo_scenario()
%RUN_DEMO_SCENARIO Run presentation-friendly representative scenarios.

rootDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(rootDir, 'scripts', 'init_project.m'));
check_visualization_toolchain(true);

sweepPath = fullfile(rootDir, 'results', 'identifier_hyperparam_sweep.mat');
if ~isfile(sweepPath)
    run_identifier_hyperparam_sweep();
end
S = load(sweepPath, 'sweepResult');
bestModel = S.sweepResult.entries(S.sweepResult.bestIndex).identifierModel;

scenarioDefs = { ...
    struct('name', 'MildWingReturn', 'theta_d', [0.18;0.12;0.02;0.01;zeros(8,1)], 'scenarioType', 'wing', 'severity', 0.15, 'damageCategory', 'wing', 'damageSeverityLevel', 'low', 'flightConditionTag', 'cruise_nominal', 'excitationType', 'step_sine', 'disturbanceGain', 0.9, 'windLevel_mps', 0, 'damageStartTime', 3.0, 'damageRampDuration', 1.0, 'assessmentDelay', 2.0), ...
    struct('name', 'CompoundDivert', 'theta_d', [0.30;0.45;0.10;0.18;0.20;0.24;0.18;0.30;0.22;0.28;0.20;0.18], 'scenarioType', 'compound', 'severity', 0.28, 'damageCategory', 'compound', 'damageSeverityLevel', 'moderate', 'flightConditionTag', 'gust_entry', 'excitationType', 'multisine', 'disturbanceGain', 1.1, 'windLevel_mps', 4, 'damageStartTime', 3.0, 'damageRampDuration', 1.0, 'assessmentDelay', 2.0), ...
    struct('name', 'SevereEgress', 'theta_d', [0.60;0.72;0.20;0.35;0.44;0.48;0.40;0.68;0.62;0.58;0.50;0.66], 'scenarioType', 'compound', 'severity', 0.52, 'damageCategory', 'compound', 'damageSeverityLevel', 'severe', 'flightConditionTag', 'low_altitude', 'excitationType', 'doublet', 'disturbanceGain', 1.25, 'windLevel_mps', 8, 'damageStartTime', 3.0, 'damageRampDuration', 1.0, 'assessmentDelay', 2.0)};

demoOutputs = repmat(struct('scenarioName', "", 'vizResult', [], 'exportPaths', [], 'identified', [], 'oracle', []), numel(scenarioDefs), 1);
for i = 1:numel(scenarioDefs)
    info = scenarioDefs{i};
    info.initialState = demo_initial_state(info.flightConditionTag);
    info.commandBias = zeros(4, 1);
    info.splitTag = 'test';
    info.datasetVersion = 'demo';
    pipeline = run_online_assessment_pipeline(info.theta_d, bestModel, bestModel.config, 'identified', info);

    modeCode = pipeline.identified.decisionOutput.modeCode;
    decisionTime = info.damageStartTime + info.assessmentDelay;
    vizInfo = info;
    vizInfo.decisionTime = decisionTime;
    vizInfo.decisionMode = pipeline.identified.decisionOutput.mode;
    sample = simulate_identifier_timeseries(info.theta_d, bestModel.config, vizInfo);

    demoResult = struct();
    demoResult.scenarioName = info.name;
    demoResult.time = sample.time;
    demoResult.stateHist = sample.stateHist;
    demoResult.etaTotalHist = build_assessment_trace(sample.time, sample.damageGate, pipeline.identified.ctrlMetrics.eta_total);
    demoResult.confidenceHist = build_confidence_trace(sample.time, info.damageStartTime, decisionTime, pipeline.identified.identifierOutput.confidence);
    demoResult.modeHist = build_mode_trace(sample.time, decisionTime, modeCode);
    demoResult.eventTimes = struct( ...
        'damageStartTime', info.damageStartTime, ...
        'decisionTime', decisionTime);
    vizResult = visualize_flight_scenario(demoResult);
    exportPaths = export_demo_figures(vizResult, fullfile(rootDir, 'results', 'demo_figures'));

    demoOutputs(i).scenarioName = string(info.name);
    demoOutputs(i).vizResult = vizResult;
    demoOutputs(i).exportPaths = exportPaths;
    demoOutputs(i).identified = pipeline.identified;
    demoOutputs(i).oracle = pipeline.oracle;

    fprintf('Demo scenario: %s\n', info.name);
    fprintf('  selected mode: %s\n', pipeline.identified.decisionOutput.mode);
    fprintf('  eta_total estimate: %.3f\n', pipeline.identified.ctrlMetrics.eta_total);
    fprintf('  confidence: %.3f\n', pipeline.identified.identifierOutput.confidence);
    fprintf('  oracle match: %d\n', strcmpi(pipeline.identified.decisionOutput.mode, pipeline.oracle.decisionOutput.mode));
end
end

function x0 = demo_initial_state(tag)
Pcfg = evalin('base', 'P');
base = [Pcfg.initial.pned_m(:); Pcfg.initial.uvw_mps(:); Pcfg.initial.euler_rad(:); Pcfg.initial.pqr_rps(:)];
switch lower(tag)
    case 'gust_entry'
        x0 = base + [0;0;200;5;0.6;0.2;deg2rad(3);deg2rad(1);0;0.02;0.01;0.03];
    case 'low_altitude'
        x0 = base + [0;0;600;-3;-0.5;0.5;deg2rad(2);deg2rad(2);0;0;0;0];
    otherwise
        x0 = base;
end
end

function etaHist = build_assessment_trace(t, damageGate, finalEta)
t = t(:);
damageGate = damageGate(:);
etaHist = 1.0 - damageGate .* (1.0 - finalEta);
etaHist(~isfinite(etaHist)) = finalEta;
etaHist = min(max(etaHist, 0.0), 1.0);
if numel(etaHist) ~= numel(t)
    etaHist = repmat(finalEta, numel(t), 1);
end
end

function confidenceHist = build_confidence_trace(t, damageStartTime, decisionTime, finalConfidence)
t = t(:);
confidenceHist = ones(numel(t), 1);
assessmentWindow = max(decisionTime - damageStartTime, eps);
idx = t >= damageStartTime;
blend = min(max((t(idx) - damageStartTime) ./ assessmentWindow, 0.0), 1.0);
confidenceHist(idx) = 1.0 - blend .* (1.0 - finalConfidence);
end

function modeHist = build_mode_trace(t, decisionTime, modeCode)
modeHist = zeros(numel(t), 1);
modeHist(t >= decisionTime) = modeCode;
end
