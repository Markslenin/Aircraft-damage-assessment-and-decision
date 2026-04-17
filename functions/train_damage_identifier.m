function [identifierModel, trainingReport] = train_damage_identifier(identifierDataset, identifierConfig)
%TRAIN_DAMAGE_IDENTIFIER Train a baseline identifier for eta-hat or theta-hat.

if nargin < 2 || isempty(identifierConfig)
    identifierConfig = get_identifier_target_config();
end

[X, Y, meta] = dataset_to_xy(identifierDataset, identifierConfig);
n = size(X, 1);
idx = randperm(n);
nTrain = max(1, floor(0.8 * n));
trainIdx = idx(1:nTrain);
testIdx = idx(nTrain+1:end);
if isempty(testIdx)
    testIdx = trainIdx;
end

mu = mean(X(trainIdx, :), 1);
sigma = std(X(trainIdx, :), 0, 1);
sigma(sigma < 1e-6) = 1.0;

Xtrain = (X(trainIdx, :) - mu) ./ sigma;
Xtest = (X(testIdx, :) - mu) ./ sigma;
Ytrain = Y(trainIdx, :);
Ytest = Y(testIdx, :);

modelType = lower(identifierConfig.primaryModelType);
lambda = 1.0;
fallbackUsed = false;

switch modelType
    case 'ridge'
        modelPayload = train_ridge_model(Xtrain, Ytrain, lambda);
    case 'mlp'
        [modelPayload, fallbackUsed] = train_mlp_model(Xtrain, Ytrain, lambda);
    otherwise
        error('Unsupported identifier model type: %s', identifierConfig.primaryModelType);
end

YhatTest = predict_model(modelPayload, Xtest);
rmse = sqrt(mean((YhatTest - Ytest).^2, 1));
mae = mean(abs(YhatTest - Ytest), 1);

identifierModel = struct();
identifierModel.modelType = modelPayload.modelType;
identifierModel.config = identifierConfig;
identifierModel.targetNames = meta.targetNames;
identifierModel.featureInfo = meta.featureInfo;
identifierModel.mu = mu;
identifierModel.sigma = sigma;
identifierModel.payload = modelPayload;
identifierModel.trainingRmse = rmse;
identifierModel.trainingMae = mae;

trainingReport = struct();
trainingReport.trainIdx = trainIdx;
trainingReport.testIdx = testIdx;
trainingReport.rmse = rmse;
trainingReport.mae = mae;
trainingReport.fallbackUsed = fallbackUsed;
trainingReport.modelType = identifierModel.modelType;
trainingReport.targetNames = meta.targetNames;
trainingReport.Ytrue = Ytest;
trainingReport.Yhat = YhatTest;
end

function [X, Y, meta] = dataset_to_xy(identifierDataset, identifierConfig)
n = numel(identifierDataset.samples);

X = [];
Y = [];
featureInfo = struct();

for i = 1:n
    sample = identifierDataset.samples(i);
    if strcmpi(identifierConfig.featureMode, 'sequence')
        [features, info] = build_identifier_features(sample.stateHist, sample.inputHist, sample.residualHist, identifierConfig);
        features = features(:).';
    else
        features = sample.featureSummary(:).';
        info = sample.featureInfo;
    end

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

function payload = train_ridge_model(X, Y, lambda)
I = eye(size(X, 2));
payload = struct();
payload.modelType = 'ridge';
payload.beta = (X' * X + lambda * I) \ (X' * Y);
payload.bias = zeros(1, size(Y, 2));
end

function [payload, fallbackUsed] = train_mlp_model(X, Y, lambda)
fallbackUsed = false;

if exist('fitrnet', 'file') == 2
    models = cell(1, size(Y, 2));
    for j = 1:size(Y, 2)
        models{j} = fitrnet(X, Y(:, j), 'LayerSizes', 12, 'Activations', 'relu', 'Standardize', false);
    end
    payload = struct('modelType', 'mlp', 'models', {models}, 'backend', 'fitrnet');
    return;
end

% Fallback keeps the interface available when no MLP toolbox is installed.
payload = train_ridge_model(X, Y, lambda);
payload.modelType = 'ridge';
fallbackUsed = true;
end

function Yhat = predict_model(payload, X)
switch lower(payload.modelType)
    case 'ridge'
        Yhat = X * payload.beta + payload.bias;
    case 'mlp'
        Yhat = zeros(size(X, 1), numel(payload.models));
        for j = 1:numel(payload.models)
            Yhat(:, j) = predict(payload.models{j}, X);
        end
    otherwise
        error('Unsupported model payload type: %s', payload.modelType);
end
end
