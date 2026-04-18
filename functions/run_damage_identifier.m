function identifierOutput = run_damage_identifier(identifierModel, features)
%RUN_DAMAGE_IDENTIFIER Run the trained identifier and report confidence.

if isstruct(features) && isfield(features, 'summaryFeatures')
    featureVector = [features.summaryFeatures(:); features.sequenceFeatures(:)].';
elseif size(features, 1) > 1
    featureVector = features(:).';
else
    featureVector = features(:).';
end

normInfo = identifierModel.normalizationInfo;
X = normalize_feature_vector(featureVector, normInfo);

yhat = predict_identifier(identifierModel.payload, X);
yhat = max(min(yhat, 1.0), 0.0);

trainX = identifierModel.trainingSetFeatures;
distances = sqrt(sum((trainX - X).^2, 2));
meanDist = mean(distances);
minDist = min(distances);
uncertaintyScore = min(1.0, minDist / max(meanDist + eps, 1e-6));

modelVariance = estimate_model_variance(identifierModel.payload, X);
confidence = max(0.05, min(0.99, exp(-minDist / max(meanDist + eps, 1e-6)) * exp(-modelVariance)));

identifierOutput = struct();
identifierOutput.rawOutput = yhat(:).';
identifierOutput.confidence = confidence;
identifierOutput.uncertaintyScore = min(1.0, 0.5 * uncertaintyScore + 0.5 * min(1.0, modelVariance));

if strcmpi(identifierModel.config.mode, 'theta')
    identifierOutput.theta_d_hat = yhat(:);
else
    identifierOutput.eta_roll_hat = yhat(1);
    identifierOutput.eta_pitch_hat = yhat(2);
    identifierOutput.eta_yaw_hat = yhat(3);
    identifierOutput.eta_total_hat = yhat(4);
end
end

function X = normalize_feature_vector(featureVector, normInfo)
switch lower(normInfo.mode)
    case 'zscore'
        X = (featureVector - normInfo.mu) ./ normInfo.sigma;
    otherwise
        X = featureVector;
end
end

function yhat = predict_identifier(payload, X)
switch lower(payload.modelType)
    case {'ridge', 'sequence_mlp_placeholder'}
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
