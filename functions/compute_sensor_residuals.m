function residualStruct = compute_sensor_residuals(measuredState, commandedInput, nominalPrediction, identifierConfig)
%COMPUTE_SENSOR_RESIDUALS Compute residuals against a unified nominal predictor.
%   Inputs:
%     measuredState    - Nx12 measured state history or 12x1 state
%     commandedInput   - Nx4 input history or 4x1 input
%     nominalPrediction - struct returned by predict_nominal_response or a
%                         struct with fields stateHist/accelHist/controlHist
%     identifierConfig - optional config, used for residual filtering
%
%   Outputs:
%     residualStruct.velResidual
%     residualStruct.angRateResidual
%     residualStruct.attitudeResidual
%     residualStruct.accelResidual
%     residualStruct.controlTrackingResidual

if nargin < 4 || isempty(identifierConfig)
    identifierConfig = get_identifier_target_config();
end

measuredState = ensure_2d(measuredState);
commandedInput = ensure_2d(commandedInput);

N = size(measuredState, 1);

if nargin < 3 || isempty(nominalPrediction)
    nominalPrediction = struct();
end

nomState = get_field_or_default(nominalPrediction, 'stateHist', measuredState);
nomAccel = get_field_or_default(nominalPrediction, 'predictedAccelHist', zeros(N, 3));
nomControl = get_field_or_default(nominalPrediction, 'controlHist', commandedInput);

nomState = resize_rows(nomState, N);
nomAccel = resize_rows(nomAccel, N);
nomControl = resize_rows(nomControl, N);

measuredAccel = estimate_body_acceleration(measuredState, identifierConfig.sequenceDt);

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

function accel = estimate_body_acceleration(stateHist, dt)
uvw = stateHist(:, 4:6);
if size(uvw, 1) == 1
    accel = zeros(1, 3);
else
    accel = [zeros(1, 3); diff(uvw, 1, 1) / max(dt, 1.0e-6)];
end
end
