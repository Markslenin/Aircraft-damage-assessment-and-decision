function identifierDataset = generate_identifier_dataset()
%GENERATE_IDENTIFIER_DATASET Build the enhanced P3 identifier dataset.

rootDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(rootDir, 'scripts', 'init_project.m'));

identifierConfig = get_identifier_target_config();
scenarioDefs = build_default_damage_scenarios();
initialStates = build_initial_state_variants();
commandBiases = {zeros(4, 1), [0.01; 0.02; 0.00; 0.05]};
excitationTypes = {'step_sine', 'chirp_like'};
disturbanceGains = [0.8, 1.2];

samples = cell(0, 1);
idx = 0;

for i = 1:numel(scenarioDefs)
    for j = 1:numel(initialStates)
        for k = 1:numel(commandBiases)
            for m = 1:numel(excitationTypes)
                idx = idx + 1;
                scenarioInfo = scenarioDefs(i);
                scenarioInfo.initialState = initialStates{j};
                scenarioInfo.commandBias = commandBiases{k};
                scenarioInfo.excitationType = excitationTypes{m};
                scenarioInfo.disturbanceGain = disturbanceGains(mod(idx - 1, numel(disturbanceGains)) + 1);
                scenarioInfo.splitTag = assign_split_tag(idx);
                sample = simulate_identifier_timeseries(scenarioDefs(i).theta_d, identifierConfig, scenarioInfo);
                sample.datasetSplitTag = scenarioInfo.splitTag;
                samples{idx, 1} = sample; %#ok<AGROW>
            end
        end
    end
end

samples = vertcat(samples{:});

identifierDataset = struct();
identifierDataset.version = 'identifier_dataset_v2';
identifierDataset.config = identifierConfig;
identifierDataset.samples = samples;
identifierDataset.createdOn = datestr(now, 30);

save(fullfile(rootDir, 'data', 'identifier_dataset.mat'), 'identifierDataset');
fprintf('Identifier dataset v2 saved with %d samples.\n', numel(samples));
end

function variants = build_initial_state_variants()
Pcfg = evalin('base', 'P');
base = [Pcfg.initial.pned_m(:); Pcfg.initial.uvw_mps(:); Pcfg.initial.euler_rad(:); Pcfg.initial.pqr_rps(:)];

variant1 = base;
variant2 = base;
variant2(4:6) = [38; 0.5; -0.5];
variant2(8) = deg2rad(4);

variant3 = base;
variant3(1:3) = [0; 0; -1500];
variant3(4:6) = [28; -0.3; 0.8];
variant3(7:9) = deg2rad([2; 3; 0.5]);

variants = {variant1, variant2, variant3};
end

function tag = assign_split_tag(idx)
modVal = mod(idx, 10);
if modVal <= 5
    tag = 'train';
elseif modVal <= 7
    tag = 'val';
else
    tag = 'test';
end
end
