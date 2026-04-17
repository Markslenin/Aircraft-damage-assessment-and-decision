function identifierDataset = generate_identifier_dataset()
%GENERATE_IDENTIFIER_DATASET Build the P2 identifier dataset.

rootDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(rootDir, 'scripts', 'init_project.m'));

identifierConfig = get_identifier_target_config();
scenarioDefs = build_default_damage_scenarios();

samples = repmat(empty_identifier_sample(), numel(scenarioDefs), 1);

for i = 1:numel(scenarioDefs)
    sample = simulate_identifier_timeseries(scenarioDefs(i).theta_d, identifierConfig, scenarioDefs(i));
    samples(i).theta_d = sample.theta_d;
    samples(i).eta_target = sample.eta_target;
    samples(i).time = sample.time;
    samples(i).stateHist = sample.stateHist;
    samples(i).inputHist = sample.inputHist;
    samples(i).residualHist = sample.residualHist;
    samples(i).featureSummary = sample.featureSummary;
    samples(i).featureInfo = sample.featureInfo;
    samples(i).scenarioInfo = sample.scenarioInfo;
    samples(i).ctrlMetrics = sample.ctrlMetrics;
    samples(i).trimInfo = sample.trimInfo;
    samples(i).decisionOutput = sample.decisionOutput;
end

identifierDataset = struct();
identifierDataset.config = identifierConfig;
identifierDataset.samples = samples;
identifierDataset.createdOn = datestr(now, 30);

save(fullfile(rootDir, 'data', 'identifier_dataset.mat'), 'identifierDataset');
fprintf('Identifier dataset saved with %d samples.\n', numel(samples));
end

function sample = empty_identifier_sample()
sample = struct( ...
    'theta_d', zeros(12, 1), ...
    'eta_target', zeros(1, 4), ...
    'time', zeros(0, 1), ...
    'stateHist', zeros(0, 12), ...
    'inputHist', zeros(0, 4), ...
    'residualHist', struct(), ...
    'featureSummary', zeros(1, 1), ...
    'featureInfo', struct(), ...
    'scenarioInfo', struct(), ...
    'ctrlMetrics', struct(), ...
    'trimInfo', struct(), ...
    'decisionOutput', struct());
end
