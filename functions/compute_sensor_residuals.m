function residualStruct = compute_sensor_residuals(measuredState, commandedInput, nominalPrediction)
%COMPUTE_SENSOR_RESIDUALS Build residual signals for the identifier.
%   Inputs:
%     measuredState   - Nx12 state history or 12x1 state vector
%     commandedInput  - Nx4 input history or 4x1 control vector
%     nominalPrediction - struct with fields:
%         stateHist, accelHist, controlHist
%
%   Outputs:
%     residualStruct.velResidual             - Nx3
%     residualStruct.angRateResidual         - Nx3
%     residualStruct.attitudeResidual        - Nx3
%     residualStruct.accelResidual           - Nx3
%     residualStruct.controlTrackingResidual - Nx4

measuredState = ensure_2d(measuredState);
commandedInput = ensure_2d(commandedInput);

N = size(measuredState, 1);

if nargin < 3 || isempty(nominalPrediction)
    nominalPrediction = struct();
end

nomState = get_field_or_default(nominalPrediction, 'stateHist', zeros(N, size(measuredState, 2)));
nomAccel = get_field_or_default(nominalPrediction, 'accelHist', zeros(N, 3));
nomControl = get_field_or_default(nominalPrediction, 'controlHist', zeros(N, size(commandedInput, 2)));

if size(nomState, 1) ~= N
    nomState = resize_rows(nomState, N);
end
if size(nomAccel, 1) ~= N
    nomAccel = resize_rows(nomAccel, N);
end
if size(nomControl, 1) ~= N
    nomControl = resize_rows(nomControl, N);
end

measuredAccel = estimate_body_acceleration(measuredState);

residualStruct = struct();
residualStruct.velResidual = measuredState(:, 4:6) - nomState(:, 4:6);
residualStruct.angRateResidual = measuredState(:, 10:12) - nomState(:, 10:12);
residualStruct.attitudeResidual = measuredState(:, 7:9) - nomState(:, 7:9);
residualStruct.accelResidual = measuredAccel - nomAccel;
residualStruct.controlTrackingResidual = commandedInput - nomControl;
end

function x = ensure_2d(x)
x = double(x);
if isvector(x)
    x = reshape(x, 1, []);
end
end

function value = get_field_or_default(S, name, defaultValue)
if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
    value = S.(name);
else
    value = defaultValue;
end
end

function x = resize_rows(x, N)
if isempty(x)
    x = zeros(N, 1);
    return;
end
if size(x, 1) == 1
    x = repmat(x, N, 1);
elseif size(x, 1) < N
    x(end+1:N, :) = repmat(x(end, :), N - size(x, 1), 1);
else
    x = x(1:N, :);
end
end

function accel = estimate_body_acceleration(stateHist)
uvw = stateHist(:, 4:6);
if size(uvw, 1) == 1
    accel = zeros(1, 3);
else
    accel = [zeros(1, 3); diff(uvw, 1, 1)];
end
end
