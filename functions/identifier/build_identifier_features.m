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
[couplingStats, couplingNames] = residual_coupling_features(residualHistory, inputHistory);
[deltaStats, deltaNames] = filtered_delta_features(residualHistory);
[normalizedSummary, normalizedNames] = normalized_feature_block(residualHistory);

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
        featureOutput = [summaryBase, residualEnergy, crossStats, couplingStats];
        featureInfo = make_info('summary_plus_cross_channel_stats', [summaryNames, energyNames, crossNames, couplingNames], {}, L);
    case 'normalized_summary'
        featureOutput = [summaryBase, normalizedSummary, deltaStats];
        featureInfo = make_info('normalized_summary', [summaryNames, normalizedNames, deltaNames], {}, L);
    case 'residual_coupling_summary'
        featureOutput = [summaryBase, residualEnergy, couplingStats, deltaStats];
        featureInfo = make_info('residual_coupling_summary', [summaryNames, energyNames, couplingNames, deltaNames], {}, L);
    case 'sequence'
        sequenceFeatures = [stateHistory(end-L+1:end, :), inputHistory(end-L+1:end, :), residualMatrix(end-L+1:end, :)];
        featureOutput = struct('rawFeatures', summaryBase, 'normalizedFeatures', normalizedSummary, 'sequenceFeatures', sequenceFeatures, 'featureMeta', struct('mode', 'sequence'));
        featureInfo = make_info('sequence', summaryNames, {'state_input_residual_sequence'}, L);
    case 'hybrid_sequence_summary'
        summaryFeatures = [summaryBase, residualEnergy, crossStats];
        sequenceFeatures = [stateHistory(end-L+1:end, :), inputHistory(end-L+1:end, :), residualMatrix(end-L+1:end, :)];
        featureOutput = struct( ...
            'rawFeatures', summaryBase, ...
            'normalizedFeatures', normalizedSummary, ...
            'summaryFeatures', summaryFeatures, ...
            'sequenceFeatures', sequenceFeatures, ...
            'featureMeta', struct('mode', 'hybrid_sequence_summary'));
        featureInfo = make_info('hybrid_sequence_summary', [summaryNames, energyNames, crossNames], {'state_input_residual_sequence'}, L);
    case 'hybrid_sequence_summary_v2'
        summaryFeatures = [summaryBase, residualEnergy, crossStats, couplingStats, deltaStats];
        sequenceFeatures = [stateHistory(end-L+1:end, :), inputHistory(end-L+1:end, :), residualMatrix(end-L+1:end, :)];
        featureOutput = struct( ...
            'rawFeatures', [summaryBase, residualEnergy, crossStats], ...
            'normalizedFeatures', [normalizedSummary, deltaStats], ...
            'summaryFeatures', summaryFeatures, ...
            'sequenceFeatures', sequenceFeatures, ...
            'featureMeta', struct('mode', 'hybrid_sequence_summary_v2'));
        featureInfo = make_info('hybrid_sequence_summary_v2', [summaryNames, energyNames, crossNames, couplingNames, deltaNames], {'state_input_residual_sequence'}, L);
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
nRows = max(size(M, 1), 1);
% Compute the 5 per-column statistics in one matrix pass each instead of
% calling mean/std/max/sum once per column inside a for loop.
meanRow = mean(M, 1);
stdRow = std(M, 0, 1);
peakRow = max(abs(M), [], 1);
slopeRow = M(end, :) - M(1, :);
energyRow = sum(M.^2, 1) / nRows;

% Interleave [mean; std; peak; slope; energy] for each channel so the layout
% matches the previous (1, 5*N) packing exactly.
statsMat = [meanRow; stdRow; peakRow; slopeRow; energyRow];
vec = reshape(statsMat, 1, 5 * N);

names = cell(1, 5 * N);
for i = 1:N
    idx = (i - 1) * 5 + (1:5);
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
% Vectorize the per-column [energy, peak] pair across the whole matrix.
energyRow = sum(M.^2, 1);
peakRow = max(abs(M), [], 1);
vec = reshape([energyRow; peakRow], 1, 2 * N);
names = cell(1, 2 * N);
for i = 1:N
    idx = (i - 1) * 2 + (1:2);
    names(idx) = {sprintf('%s_%d_energy_only', prefix, i), sprintf('%s_%d_peak_only', prefix, i)};
end

if size(M, 2) >= 9
    rollEnergy = sum(M(:, 4:6).^2, 'all');
    pitchEnergy = sum(M(:, 7:9).^2, 'all');
    yawEnergy = sum(M(:, 1:3).^2, 'all');
    vec = [vec, ...
        safe_ratio(rollEnergy, pitchEnergy), ...
        safe_ratio(rollEnergy, yawEnergy), ...
        safe_ratio(pitchEnergy, yawEnergy)];
    names = [names, ...
        {sprintf('%s_roll_pitch_energy_ratio', prefix), ...
         sprintf('%s_roll_yaw_energy_ratio', prefix), ...
         sprintf('%s_pitch_yaw_energy_ratio', prefix)}];
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

function [vec, names] = residual_coupling_features(residualHistory, inputHistory)
att = residualHistory.attitudeResidual;
rate = residualHistory.angRateResidual;
vel = residualHistory.velResidual;
ctrl = inputHistory;
vec = [ ...
    safe_corr(mean(abs(att), 2), mean(abs(rate), 2)), ...
    safe_corr(att(:, 1), rate(:, 1)), ...
    safe_corr(att(:, 2), rate(:, 2)), ...
    safe_corr(att(:, 3), rate(:, 3)), ...
    safe_corr(ctrl(:, min(2, size(ctrl, 2))), vel(:, 2)), ...
    safe_delay_proxy(ctrl(:, min(2, size(ctrl, 2))), rate(:, 1)), ...
    safe_delay_proxy(ctrl(:, 1), rate(:, 2)), ...
    safe_delay_proxy(ctrl(:, min(3, size(ctrl, 2))), rate(:, 3))];
names = { ...
    'coupling_attitude_rate_mean', ...
    'coupling_roll_att_rate', ...
    'coupling_pitch_att_rate', ...
    'coupling_yaw_att_rate', ...
    'coupling_aileron_vel', ...
    'delay_proxy_aileron_roll', ...
    'delay_proxy_elevator_pitch', ...
    'delay_proxy_rudder_yaw'};
end

function [vec, names] = filtered_delta_features(residualHistory)
if isfield(residualHistory, 'deltaVsRaw')
    M = [ ...
        residualHistory.deltaVsRaw.velResidual, ...
        residualHistory.deltaVsRaw.angRateResidual, ...
        residualHistory.deltaVsRaw.attitudeResidual, ...
        residualHistory.deltaVsRaw.accelResidual, ...
        residualHistory.deltaVsRaw.controlTrackingResidual];
else
    M = zeros(size(residualHistory.velResidual, 1), 16);
end
[vec, names] = summarize_matrix(M, 'filtered_delta');
end

function [vec, names] = normalized_feature_block(residualHistory)
if isfield(residualHistory, 'normalized')
    M = [ ...
        residualHistory.normalized.velResidual, ...
        residualHistory.normalized.angRateResidual, ...
        residualHistory.normalized.attitudeResidual, ...
        residualHistory.normalized.accelResidual, ...
        residualHistory.normalized.controlTrackingResidual];
else
    M = zeros(size(residualHistory.velResidual, 1), 16);
end
[vec, names] = summarize_matrix(M, 'normalized_residual');
end

function r = safe_ratio(a, b)
r = a / max(abs(b), 1.0e-6);
end

function d = safe_delay_proxy(u, y)
u = u(:);
y = y(:);
if numel(u) < 3 || numel(y) < 3
    d = 0;
    return;
end
c0 = safe_corr(u, y);
c1 = safe_corr(u(1:end-1), y(2:end));
d = c1 - c0;
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
