function [identifierModel, normalizationInfo, trainingReport] = train_damage_identifier(identifierDataset, identifierConfig)
%TRAIN_DAMAGE_IDENTIFIER Train pluggable baseline identifier models.

if nargin < 2 || isempty(identifierConfig)
    identifierConfig = get_identifier_target_config();
end

if isfield(identifierConfig, 'trainingOptions')
    modelConfig = identifierConfig;
    targetConfig = identifierConfig.identifierTargetConfig;
else
    modelConfig = get_identifier_model_config(identifierConfig.primaryModelType, identifierConfig.featureMode);
    targetConfig = identifierConfig;
    modelConfig.identifierTargetConfig = targetConfig;
end

[X, Y, meta] = dataset_to_xy(identifierDataset, targetConfig);
[trainIdx, valIdx, testIdx] = split_dataset(identifierDataset, size(X, 1), modelConfig.trainingOptions);

[Xnorm, normalizationInfo] = normalize_features(X, trainIdx, modelConfig.normalizationMode);
Ytrain = Y(trainIdx, :);
Xtrain = Xnorm(trainIdx, :);
Xval = Xnorm(valIdx, :);
Xtest = Xnorm(testIdx, :);
Yval = Y(valIdx, :);
Ytest = Y(testIdx, :);

modelType = lower(modelConfig.modelType);
fallbackUsed = false;

switch modelType
    case 'ridge'
        payload = train_ridge_model(Xtrain, Ytrain, modelConfig.trainingOptions.ridgeLambda);
    case 'shallow_mlp'
        [payload, fallbackUsed] = train_shallow_mlp_model(Xtrain, Ytrain, modelConfig.trainingOptions);
    case 'sequence_mlp_placeholder'
        payload = train_sequence_placeholder_model(Xtrain, Ytrain, modelConfig.trainingOptions);
        fallbackUsed = true;
    case 'ensemble_summary'
        [payload, fallbackUsed] = train_ensemble_summary_model(Xtrain, Ytrain, modelConfig.trainingOptions);
    otherwise
        error('Unsupported modelType: %s', modelConfig.modelType);
end

YhatVal = predict_payload(payload, Xval);
YhatTest = predict_payload(payload, Xtest);

identifierModel = struct();
identifierModel.modelType = payload.modelType;
identifierModel.config = targetConfig;
identifierModel.modelConfig = modelConfig;
identifierModel.targetNames = meta.targetNames;
identifierModel.featureInfo = meta.featureInfo;
identifierModel.normalizationInfo = normalizationInfo;
identifierModel.payload = payload;
identifierModel.trainingSetFeatures = Xnorm(trainIdx, :);
identifierModel.trainingSetTargets = Ytrain;

trainingReport = struct();
trainingReport.trainIdx = trainIdx;
trainingReport.valIdx = valIdx;
trainingReport.testIdx = testIdx;
trainingReport.fallbackUsed = fallbackUsed;
trainingReport.modelType = identifierModel.modelType;
trainingReport.targetNames = meta.targetNames;
trainingReport.valRmse = rmse(Yval, YhatVal);
trainingReport.valMae = mae(Yval, YhatVal);
trainingReport.testRmse = rmse(Ytest, YhatTest);
trainingReport.testMae = mae(Ytest, YhatTest);
trainingReport.Ytrue = Ytest;
trainingReport.Yhat = YhatTest;
trainingReport.validationPrediction = YhatVal;
trainingReport.validationTruth = Yval;
end

function [X, Y, meta] = dataset_to_xy(identifierDataset, identifierConfig)
n = numel(identifierDataset.samples);
X = [];
Y = [];
featureInfo = struct();

for i = 1:n
    sample = identifierDataset.samples(i);
    [features, info] = select_sample_features(sample, identifierConfig);
    X(i, :) = features; %#ok<AGROW>
    if strcmpi(identifierConfig.mode, 'theta')
        Y(i, :) = sample.theta_d(:).'; %#ok<AGROW>
        targetNames = identifierConfig.targetNamesTheta;
    else
        Y(i, :) = sample.eta_target(:).'; %#ok<AGROW>
        targetNames = identifierConfig.targetNames;
    end
    featureInfo = info;
end

meta = struct('featureInfo', featureInfo, 'targetNames', {targetNames});
end

function [features, info] = select_sample_features(sample, identifierConfig)
if isfield(sample, 'featureModeReadyData') && isfield(sample.featureModeReadyData, identifierConfig.featureMode)
    featureData = sample.featureModeReadyData.(identifierConfig.featureMode);
else
    featureData = [];
end

if isempty(featureData)
    [featureData, info] = build_identifier_features(sample.stateHist, sample.inputHist, sample.residualFilteredHist, identifierConfig);
else
    info = sample.featureInfo;
end

if isstruct(featureData)
    features = [featureData.summaryFeatures(:); featureData.sequenceFeatures(:)].';
else
    features = featureData(:).';
end
end

function [trainIdx, valIdx, testIdx] = split_dataset(identifierDataset, n, opts)
if isfield(identifierDataset.samples, 'datasetSplitTag')
    tags = strings(n, 1);
    for i = 1:n
        tags(i) = string(identifierDataset.samples(i).datasetSplitTag);
    end
    trainIdx = find(tags == "train");
    valIdx = find(tags == "val");
    testIdx = find(tags == "test");
    if ~isempty(trainIdx) && ~isempty(valIdx) && ~isempty(testIdx)
        return;
    end
end

idx = randperm(n);
nTrain = max(1, floor(opts.trainFraction * n));
nVal = max(1, floor(opts.valFraction * n));
trainIdx = idx(1:nTrain);
valIdx = idx(nTrain+1:min(nTrain+nVal, n));
testIdx = idx(min(nTrain+nVal+1, n):end);
if isempty(valIdx)
    valIdx = trainIdx;
end
if isempty(testIdx)
    testIdx = valIdx;
end
end

function [Xnorm, info] = normalize_features(X, trainIdx, modeName)
switch lower(modeName)
    case 'zscore'
        mu = mean(X(trainIdx, :), 1);
        sigma = std(X(trainIdx, :), 0, 1);
        sigma(sigma < 1.0e-6) = 1.0;
        Xnorm = (X - mu) ./ sigma;
        info = struct('mode', 'zscore', 'mu', mu, 'sigma', sigma);
    otherwise
        Xnorm = X;
        info = struct('mode', 'none', 'mu', zeros(1, size(X, 2)), 'sigma', ones(1, size(X, 2)));
end
end

function payload = train_ridge_model(X, Y, lambda)
I = eye(size(X, 2));
payload = struct('modelType', 'ridge');
payload.beta = (X' * X + lambda * I) \ (X' * Y);
payload.bias = zeros(1, size(Y, 2));
payload.trainingVariance = var(Y, 0, 1);
end

function [payload, fallbackUsed] = train_shallow_mlp_model(X, Y, opts)
fallbackUsed = false;
if exist('fitrnet', 'file') == 2
    models = cell(1, size(Y, 2));
    for j = 1:size(Y, 2)
        models{j} = fitrnet(X, Y(:, j), 'LayerSizes', opts.hiddenLayerSize, 'Activations', 'relu', 'Standardize', false);
    end
    payload = struct('modelType', 'shallow_mlp', 'models', {models}, 'trainingVariance', var(Y, 0, 1));
else
    payload = train_ridge_model(X, Y, opts.ridgeLambda);
    payload.modelType = 'ridge';
    fallbackUsed = true;
end
end

function payload = train_sequence_placeholder_model(X, Y, opts)
% TODO: Replace with a true LSTM/temporal model when toolchain allows.
payload = train_ridge_model(X, Y, opts.ridgeLambda);
payload.modelType = 'sequence_mlp_placeholder';
end

function [payload, fallbackUsed] = train_ensemble_summary_model(X, Y, opts)
[ridgePayload] = train_ridge_model(X, Y, opts.ridgeLambda);
[mlpPayload, fallbackUsed] = train_shallow_mlp_model(X, Y, opts);
payload = struct();
payload.modelType = 'ensemble_summary';
payload.members = {ridgePayload, mlpPayload};
payload.trainingVariance = var(Y, 0, 1);
end

function Yhat = predict_payload(payload, X)
switch lower(payload.modelType)
    case {'ridge', 'sequence_mlp_placeholder'}
        Yhat = X * payload.beta + payload.bias;
    case 'shallow_mlp'
        Yhat = zeros(size(X, 1), numel(payload.models));
        for j = 1:numel(payload.models)
            Yhat(:, j) = predict(payload.models{j}, X);
        end
    case 'ensemble_summary'
        Ymember = cellfun(@(m) predict_payload(m, X), payload.members, 'UniformOutput', false);
        Ystack = cat(3, Ymember{:});
        Yhat = mean(Ystack, 3);
    otherwise
        error('Unsupported model payload type: %s', payload.modelType);
end
end

function out = rmse(Ytrue, Yhat)
out = sqrt(mean((Yhat - Ytrue).^2, 1));
end

function out = mae(Ytrue, Yhat)
out = mean(abs(Yhat - Ytrue), 1);
end
