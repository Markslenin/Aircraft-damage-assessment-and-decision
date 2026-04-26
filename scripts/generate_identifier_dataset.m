function identifierDataset = generate_identifier_dataset()
%GENERATE_IDENTIFIER_DATASET Build the balanced P3.5 identifier dataset v3.

rootDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(rootDir, 'scripts', 'init_project.m'));

identifierConfig = get_identifier_target_config();
% Dataset generation feeds multi-config sweeps that may exercise any of the
% supported featureModes, so opt in to building all of them up-front.
identifierConfig.precomputeAllFeatureModes = true;
scenarioDefs = build_dataset_v3_scenarios();
initialStates = build_initial_state_variants_v3();
commandBiases = build_command_bias_variants();
excitationTypes = {'step_sine', 'chirp_like', 'doublet', 'multisine'};
Pcfg = get_project_params();
windLevels = Pcfg.environment.windLevels_mps;

totalSamples = numel(scenarioDefs) * numel(initialStates) * numel(commandBiases) * numel(excitationTypes);
samples = cell(totalSamples, 1);
idx = 0;

for i = 1:numel(scenarioDefs)
    for j = 1:numel(initialStates)
        for k = 1:numel(commandBiases)
            for m = 1:numel(excitationTypes)
                windLevel = windLevels(mod(idx, numel(windLevels)) + 1);
                idx = idx + 1;
                scenarioInfo = scenarioDefs(i);
                scenarioInfo.initialState = initialStates{j}.state;
                scenarioInfo.flightConditionTag = initialStates{j}.tag;
                scenarioInfo.commandBias = commandBiases{k}.bias;
                scenarioInfo.excitationType = excitationTypes{m};
                scenarioInfo.excitationTypeTag = commandBiases{k}.tag;
                scenarioInfo.disturbanceGain = 0.7 + 0.2 * j + 0.1 * k;
                scenarioInfo.windLevel_mps = windLevel;
                scenarioInfo.datasetVersion = 'identifier_dataset_v3';
                scenarioInfo.splitTag = assign_split_tag_v3(idx, scenarioInfo.damageCategory, scenarioInfo.damageSeverityLevel);
                sample = simulate_identifier_timeseries(scenarioDefs(i).theta_d, identifierConfig, scenarioInfo);
                sample.damageCategory = string(scenarioInfo.damageCategory);
                sample.damageSeverityLevel = string(scenarioInfo.damageSeverityLevel);
                sample.excitationType = string(scenarioInfo.excitationType);
                sample.flightConditionTag = string(scenarioInfo.flightConditionTag);
                sample.datasetVersion = "identifier_dataset_v3";
                sample.scenarioInfo.excitationType = scenarioInfo.excitationType;
                sample.scenarioInfo.excitationTypeTag = scenarioInfo.excitationTypeTag;
                sample.scenarioInfo.windLevel_mps = windLevel;
                samples{idx, 1} = sample;
            end
        end
    end
end

samples = vertcat(samples{:});

identifierDataset = struct();
identifierDataset.version = 'identifier_dataset_v3';
identifierDataset.config = identifierConfig;
identifierDataset.samples = samples;
identifierDataset.createdOn = datestr(now, 30);
identifierDataset.notes = 'Balanced P3.5 dataset with broader damage, flight-condition, wind, and excitation coverage.';

primaryDatasetPath = fullfile(rootDir, 'data', 'identifier_dataset_v3.mat');
save(primaryDatasetPath, 'identifierDataset');
copyfile(primaryDatasetPath, fullfile(rootDir, 'data', 'identifier_dataset.mat'));
fprintf('Identifier dataset v3 saved with %d samples.\n', numel(samples));
end

function defs = build_dataset_v3_scenarios()
severities = [0.15, 0.35, 0.55, 0.75];
severityTags = {'low', 'moderate', 'high', 'severe'};
defs = struct('scenarioType', {}, 'severity', {}, 'theta_d', {}, 'damageCategory', {}, 'damageSeverityLevel', {});
idx = 0;

for s = 1:numel(severities)
    sev = severities(s);
    idx = idx + 1;
    defs(idx) = make_def('wing', sev, severityTags{s}, [sev; 0.7 * sev; 0.15 * sev; 0.1 * sev; zeros(8, 1)]);
    idx = idx + 1;
    defs(idx) = make_def('tail', sev, severityTags{s}, [zeros(4, 1); 0.8 * sev; sev; 0.6 * sev; zeros(5, 1)]);
    idx = idx + 1;
    defs(idx) = make_def('control', sev, severityTags{s}, [zeros(7, 1); 0.8 * sev; sev; 0.9 * sev; 0.7 * sev; 0.2 * sev]);
    idx = idx + 1;
    defs(idx) = make_def('thrust', sev, severityTags{s}, [zeros(11, 1); sev]);
    idx = idx + 1;
    defs(idx) = make_def('compound', sev, severityTags{s}, [ ...
        0.5 * sev; sev; 0.3 * sev; 0.75 * sev; ...
        0.4 * sev; 0.6 * sev; 0.5 * sev; ...
        0.6 * sev; 0.7 * sev; 0.5 * sev; 0.45 * sev; 0.65 * sev]);
end
end

function def = make_def(typeName, severity, severityTag, theta_d)
def = struct( ...
    'scenarioType', typeName, ...
    'severity', severity, ...
    'theta_d', min(max(theta_d(:), 0), 1), ...
    'damageCategory', typeName, ...
    'damageSeverityLevel', severityTag);
end

function variants = build_initial_state_variants_v3()
Pcfg = get_project_params();
base = [Pcfg.initial.pned_m(:); Pcfg.initial.uvw_mps(:); Pcfg.initial.euler_rad(:); Pcfg.initial.pqr_rps(:)];

variants = { ...
    struct('tag', 'cruise_nominal', 'state', base), ...
    struct('tag', 'cruise_fast', 'state', perturb_state(base, [0; 0; 0; 8; 0.5; -0.3; 0; deg2rad(3); 0; 0; 0; 0])), ...
    struct('tag', 'low_altitude', 'state', perturb_state(base, [0; 0; 800; -4; -0.4; 0.5; deg2rad(2); deg2rad(2); 0; 0; 0; 0])), ...
    struct('tag', 'gust_entry', 'state', perturb_state(base, [0; 0; 300; 2; 0.8; 0.2; deg2rad(4); deg2rad(1); deg2rad(0.5); 0.02; 0.01; 0.03]))};
end

function x = perturb_state(base, delta)
x = base + delta;
end

function biases = build_command_bias_variants()
biases = { ...
    struct('tag', 'trim', 'bias', zeros(4, 1)), ...
    struct('tag', 'mild_pitchup', 'bias', [0.00; 0.03; 0.00; 0.04]), ...
    struct('tag', 'lateral_hold', 'bias', [0.02; 0.00; 0.02; 0.02])};
end

function tag = assign_split_tag_v3(idx, damageCategory, severityTag)
key = double(sum(char(damageCategory)) + sum(char(severityTag)) + idx);
bucket = mod(key, 10);
if bucket <= 5
    tag = 'train';
elseif bucket <= 7
    tag = 'val';
else
    tag = 'test';
end
end
