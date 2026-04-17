function [featureOutput, featureInfo] = build_identifier_features(stateHistory, inputHistory, residualHistory, identifierConfig)
%BUILD_IDENTIFIER_FEATURES Convert histories into summary or sequence features.
%
% featureMode 'summary'  -> 1xD feature vector
% featureMode 'sequence' -> LxD stacked feature sequence

if nargin < 4 || isempty(identifierConfig)
    identifierConfig = get_identifier_target_config();
end

stateHistory = ensure_rows(stateHistory);
inputHistory = ensure_rows(inputHistory);
residualMatrix = residual_struct_to_matrix(residualHistory);

if strcmpi(identifierConfig.featureMode, 'sequence')
    L = min(identifierConfig.sequenceLength, size(stateHistory, 1));
    stacked = [stateHistory, inputHistory, residualMatrix];
    featureOutput = stacked(end-L+1:end, :);
    featureInfo = struct('mode', 'sequence', 'featureNames', {{}}, 'sequenceLength', L);
    return;
end

[stateVec, stateNames] = summarize_matrix(stateHistory, 'state');
[inputVec, inputNames] = summarize_matrix(inputHistory, 'input');
[residualVec, residualNames] = summarize_matrix(residualMatrix, 'residual');

featureOutput = [stateVec, inputVec, residualVec];
featureInfo = struct( ...
    'mode', 'summary', ...
    'featureNames', [{stateNames}, {inputNames}, {residualNames}], ...
    'sequenceLength', size(stateHistory, 1));
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
        sprintf('%s_%d_maxabs', prefix, i), ...
        sprintf('%s_%d_slope', prefix, i), ...
        sprintf('%s_%d_energy', prefix, i)};
end
end
