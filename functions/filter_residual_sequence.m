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

for i = 1:numel(fields)
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
end
end

function y = smooth_columns(x, windowLength)
x = double(x);
if isempty(x)
    y = x;
    return;
end

kernel = ones(windowLength, 1) / windowLength;
y = zeros(size(x));
for c = 1:size(x, 2)
    y(:, c) = conv(x(:, c), kernel, 'same');
end
end
