function [featureOutput, featureInfo] = build_identifier_features(stateHistory, inputHistory, residualHistory, identifierConfig)
%BUILD_IDENTIFIER_FEATURES Construct P3 summary/sequence/hybrid features.

if nargin < 4 || isempty(identifierConfig)
    identifierConfig = get_identifier_target_config();
end

stateHistory = ensure_rows(stateHistory);
inputHistory = ensure_rows(inputHistory);
residualMatrix = residual_struct_to_matrix(residualHistory);
featureMode = lower(identifierConfig.featureMode);
L = min(identifierConfig.sequenceLength, size(stateHistory, 1));

[stateSummary, stateNames] = summarize_matrix(stateHistory, 'state');
[inputSummary, inputNames] = summarize_matrix(inputHistory, 'input');
[residualSummary, residualNames] = summarize_matrix(residualMatrix, 'residual');
[residualEnergy, energyNames] = residual_energy_features(residualMatrix, 'residual');
[crossStats, crossNames] = cross_channel_features(stateHistory, inputHistory, residualMatrix);

summaryBase = [stateSummary, inputSummary, residualSummary];
summaryNames = [{stateNames}, {inputNames}, {residualNames}];

switch featureMode
    case 'summary'
        featureOutput = summaryBase;
        featureInfo = make_info('summary', summaryNames, {}, L);
    case 'summary_plus_residual_energy'
        featureOutput = [summaryBase, residualEnergy];
        featureInfo = make_info('summary_plus_residual_energy', [summaryNames, energyNames], {}, L);
    case 'summary_plus_cross_channel_stats'
        featureOutput = [summaryBase, residualEnergy, crossStats];
        featureInfo = make_info('summary_plus_cross_channel_stats', [summaryNames, energyNames, crossNames], {}, L);
    case 'sequence'
        sequenceFeatures = [stateHistory(end-L+1:end, :), inputHistory(end-L+1:end, :), residualMatrix(end-L+1:end, :)];
        featureOutput = sequenceFeatures;
        featureInfo = make_info('sequence', {}, {'state_input_residual_sequence'}, L);
    case 'hybrid_sequence_summary'
        summaryFeatures = [summaryBase, residualEnergy, crossStats];
        sequenceFeatures = [stateHistory(end-L+1:end, :), inputHistory(end-L+1:end, :), residualMatrix(end-L+1:end, :)];
        featureOutput = struct( ...
            'summaryFeatures', summaryFeatures, ...
            'sequenceFeatures', sequenceFeatures);
        featureInfo = make_info('hybrid_sequence_summary', [summaryNames, energyNames, crossNames], {'state_input_residual_sequence'}, L);
    otherwise
        error('Unsupported featureMode: %s', identifierConfig.featureMode);
end
end

function info = make_info(modeName, summaryNames, sequenceNames, sequenceLength)
info = struct( ...
    'mode', modeName, ...
    'summaryFeatureNames', {summaryNames}, ...
    'sequenceFeatureNames', {sequenceNames}, ...
    'sequenceLength', sequenceLength);
end

function x = ensure_rows(x)
x = double(x);
if isvector(x)
    x = reshape(x, [], numel(x));
end
end

function mat = residual_struct_to_matrix(residualHistory)
mat = [ ...
    residualHistory.velResidual, ...
    residualHistory.angRateResidual, ...
    residualHistory.attitudeResidual, ...
    residualHistory.accelResidual, ...
    residualHistory.controlTrackingResidual];
end

function [vec, names] = summarize_matrix(M, prefix)
if isempty(M)
    vec = zeros(1, 5);
    names = arrayfun(@(k) sprintf('%s_%d', prefix, k), 1:numel(vec), 'UniformOutput', false);
    return;
end

N = size(M, 2);
vec = zeros(1, 5 * N);
names = cell(1, 5 * N);

for i = 1:N
    col = M(:, i);
    stats = [ ...
        mean(col), ...
        std(col), ...
        max(abs(col)), ...
        col(end) - col(1), ...
        sum(col.^2) / max(numel(col), 1)];
    idx = (i - 1) * 5 + (1:5);
    vec(idx) = stats;
    names(idx) = { ...
        sprintf('%s_%d_mean', prefix, i), ...
        sprintf('%s_%d_std', prefix, i), ...
        sprintf('%s_%d_peak', prefix, i), ...
        sprintf('%s_%d_slope', prefix, i), ...
        sprintf('%s_%d_energy', prefix, i)};
end
end

function [vec, names] = residual_energy_features(M, prefix)
if isempty(M)
    vec = zeros(1, 1);
    names = {sprintf('%s_energy_total', prefix)};
    return;
end
N = size(M, 2);
vec = zeros(1, 2 * N);
names = cell(1, 2 * N);
for i = 1:N
    col = M(:, i);
    idx = (i - 1) * 2 + (1:2);
    vec(idx) = [sum(col.^2), max(abs(col))];
    names(idx) = {sprintf('%s_%d_energy_only', prefix, i), sprintf('%s_%d_peak_only', prefix, i)};
end
end

function [vec, names] = cross_channel_features(stateHistory, inputHistory, residualMatrix)
stateDelta = [zeros(1, size(stateHistory, 2)); diff(stateHistory, 1, 1)];
vec = zeros(1, 8);
names = { ...
    'corr_input_throttle_vs_du', ...
    'corr_input_elevator_vs_dtheta', ...
    'corr_input_aileron_vs_dphi', ...
    'corr_input_rudder_vs_dpsi', ...
    'corr_residual_vel_vs_residual_accel', ...
    'corr_residual_rate_vs_residual_attitude', ...
    'mean_abs_input_change', ...
    'mean_abs_state_change'};

vec(1) = safe_corr(inputHistory(:, min(4, size(inputHistory, 2))), stateDelta(:, 4));
vec(2) = safe_corr(inputHistory(:, 1), stateDelta(:, 8));
vec(3) = safe_corr(inputHistory(:, min(2, size(inputHistory, 2))), stateDelta(:, 7));
vec(4) = safe_corr(inputHistory(:, min(3, size(inputHistory, 2))), stateDelta(:, 9));
vec(5) = safe_corr(mean(abs(residualMatrix(:, 1:3)), 2), mean(abs(residualMatrix(:, 10:12)), 2));
vec(6) = safe_corr(mean(abs(residualMatrix(:, 4:6)), 2), mean(abs(residualMatrix(:, 7:9)), 2));
vec(7) = mean(abs(diff(inputHistory, 1, 1)), 'all');
vec(8) = mean(abs(diff(stateHistory, 1, 1)), 'all');
end

function c = safe_corr(a, b)
a = double(a(:));
b = double(b(:));
if numel(a) ~= numel(b) || numel(a) < 2 || std(a) < 1e-9 || std(b) < 1e-9
    c = 0;
else
    c = corr(a, b);
    if ~isfinite(c)
        c = 0;
    end
end
end
