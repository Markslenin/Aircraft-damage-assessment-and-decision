function residualFiltered = filter_residual_sequence(residualStruct, identifierConfig)
%FILTER_RESIDUAL_SEQUENCE Apply lightweight filtering to residual histories.
%   Supported modes:
%     moving_average
%     lowpass_placeholder

if nargin < 2 || isempty(identifierConfig)
    identifierConfig = get_identifier_target_config();
end

modeName = lower(identifierConfig.residualFilterMode);
windowLength = max(1, identifierConfig.residualWindowLength);

fields = fieldnames(residualStruct);
residualFiltered = struct();
residualDelta = struct();

for i = 1:numel(fields)
    if isstruct(residualStruct.(fields{i}))
        continue;
    end
    value = residualStruct.(fields{i});
    switch modeName
        case 'moving_average'
            residualFiltered.(fields{i}) = smooth_columns(value, windowLength);
        case 'lowpass_placeholder'
            % TODO: Replace this placeholder with a proper digital low-pass filter.
            residualFiltered.(fields{i}) = smooth_columns(value, max(2, windowLength));
        otherwise
            residualFiltered.(fields{i}) = value;
    end
    residualDelta.(fields{i}) = residualFiltered.(fields{i}) - value;
end

residualFiltered.deltaVsRaw = residualDelta;
end

function y = smooth_columns(x, windowLength)
x = double(x);
if isempty(x)
    y = x;
    return;
end
% movmean operates per-column on a matrix in a single vectorized call,
% replacing the per-column conv loop. The 'Endpoints','shrink' rule averages
% the available samples near the boundary, matching the previous 'same' conv
% behavior closely while avoiding the artificial zero-padding bias.
y = movmean(x, windowLength, 1, 'Endpoints', 'shrink');
end
