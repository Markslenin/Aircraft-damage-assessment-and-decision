function identifierOutput = run_damage_identifier(identifierModel, features)
%RUN_DAMAGE_IDENTIFIER Run a trained identifier with P3.5 metadata.

featureVector = flatten_feature_input(features);
normInfo = identifierModel.normalizationInfo.features;
X = normalize_feature_vector(featureVector, normInfo);

yhatNorm = predict_identifier(identifierModel.payload, X);
yhat = denormalize_targets(yhatNorm, identifierModel.normalizationInfo.labels);
yhat(~isfinite(yhat)) = 0;
yhat = max(min(yhat, 1.0), 0.0);

[distanceStats, neighborMean] = estimate_training_distance(identifierModel.trainingSetFeatures, identifierModel.trainingSetTargets, X);
modelVariance = estimate_model_variance(identifierModel.payload, X);
rawUncertainty = min(1.0, 0.55 * distanceStats.relativeMinDistance + 0.45 * min(1.0, modelVariance));
confidence = max(0.05, min(0.99, exp(-1.25 * distanceStats.relativeMinDistance) * exp(-0.75 * modelVariance)));

if numel(yhat) == 4
    yhatSmoothed = confidence * yhat(:).' + (1 - confidence) * neighborMean(:).';
else
    yhatSmoothed = yhat(:).';
end

identifierOutput = struct();
identifierOutput.rawOutput = yhat(:).';
identifierOutput.smoothedOutput = yhatSmoothed(:).';
identifierOutput.confidence = confidence;
identifierOutput.uncertaintyScore = rawUncertainty;
identifierOutput.modelTypeUsed = string(identifierModel.modelType);
identifierOutput.featureModeUsed = string(identifierModel.modelConfig.featureMode);
identifierOutput.predictionMeta = struct( ...
    'relativeMinDistance', distanceStats.relativeMinDistance, ...
    'minDistance', distanceStats.minDistance, ...
    'meanDistance', distanceStats.meanDistance, ...
    'neighborMean', neighborMean(:).', ...
    'modelVariance', modelVariance);

if strcmpi(identifierModel.config.mode, 'theta')
    identifierOutput.theta_d_hat = yhatSmoothed(:);
else
    identifierOutput.eta_roll_hat = yhatSmoothed(1);
    identifierOutput.eta_pitch_hat = yhatSmoothed(2);
    identifierOutput.eta_yaw_hat = yhatSmoothed(3);
    identifierOutput.eta_total_hat = yhatSmoothed(4);
end
end

function featureVector = flatten_feature_input(features)
if isstruct(features)
    fieldsInOrder = {'summaryFeatures', 'normalizedFeatures', 'sequenceFeatures', 'rawFeatures'};
    parts = {};
    for i = 1:numel(fieldsInOrder)
        if isfield(features, fieldsInOrder{i})
            parts{end + 1} = features.(fieldsInOrder{i})(:); %#ok<AGROW>
        end
    end
    if isempty(parts)
        featureVector = zeros(1, 1);
    else
        featureVector = vertcat(parts{:}).';
    end
else
    featureVector = features(:).';
end
end

function X = normalize_feature_vector(featureVector, normInfo)
expectedLength = numel(normInfo.mu);
if numel(featureVector) < expectedLength
    featureVector(1, end + 1:expectedLength) = 0;
elseif numel(featureVector) > expectedLength
    featureVector = featureVector(1:expectedLength);
end
switch lower(normInfo.mode)
    case 'zscore'
        X = (featureVector - normInfo.mu) ./ normInfo.sigma;
    otherwise
        X = featureVector;
end
end

function yhat = predict_identifier(payload, X)
switch lower(payload.modelType)
    case {'ridge', 'sequence_placeholder'}
        yhat = X * payload.beta + payload.bias;
    case 'shallow_mlp'
        yhat = zeros(1, numel(payload.models));
        for j = 1:numel(payload.models)
            yhat(j) = predict(payload.models{j}, X);
        end
    case 'ensemble_summary'
        yMembers = cellfun(@(m) predict_identifier(m, X), payload.members, 'UniformOutput', false);
        yStack = cat(3, yMembers{:});
        yhat = mean(yStack, 3);
    otherwise
        error('Unsupported identifier payload type: %s', payload.modelType);
end
end

function [stats, neighborMean] = estimate_training_distance(trainX, trainY, X)
distances = sqrt(sum((trainX - X).^2, 2));
meanDist = mean(distances);
minDist = min(distances);
[~, order] = sort(distances, 'ascend');
k = min(5, numel(order));
neighborMean = mean(trainY(order(1:k), :), 1);
stats = struct( ...
    'meanDistance', meanDist, ...
    'minDistance', minDist, ...
    'relativeMinDistance', minDist / max(meanDist + eps, 1.0e-6));
end

function varianceProxy = estimate_model_variance(payload, X)
switch lower(payload.modelType)
    case 'ensemble_summary'
        yMembers = cellfun(@(m) predict_identifier(m, X), payload.members, 'UniformOutput', false);
        yStack = squeeze(cat(3, yMembers{:}));
        varianceProxy = mean(var(yStack, 0, 2));
    otherwise
        varianceProxy = 0.05;
end
end
