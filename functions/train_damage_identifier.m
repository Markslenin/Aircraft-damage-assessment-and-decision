function [identifierModel, normalizationInfo, trainingReport] = train_damage_identifier(identifierDataset, identifierConfig)
%TRAIN_DAMAGE_IDENTIFIER Train pluggable identifier models with P3.5 bookkeeping.

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
sampleWeights = compute_sample_weights(identifierDataset, modelConfig.trainingOptions.sampleWeightingMode);

[Xnorm, normalizationInfo.features] = normalize_block(X, trainIdx, modelConfig.normalizationMode);
[Ynorm, normalizationInfo.labels] = normalize_block(Y, trainIdx, modelConfig.labelNormalizationMode);
normalizationInfo.summary = struct( ...
    'featureMode', normalizationInfo.features.mode, ...
    'labelMode', normalizationInfo.labels.mode, ...
    'featureCount', size(X, 2), ...
    'targetCount', size(Y, 2));

Xtrain = Xnorm(trainIdx, :);
Ytrain = Ynorm(trainIdx, :);
Wtrain = sampleWeights(trainIdx);
Xval = Xnorm(valIdx, :);
Yval = Y(valIdx, :);
Xtest = Xnorm(testIdx, :);
Ytest = Y(testIdx, :);

modelType = lower(modelConfig.modelType);
fallbackUsed = false;

switch modelType
    case 'ridge'
        payload = train_ridge_model(Xtrain, Ytrain, Wtrain, modelConfig.trainingOptions.ridgeLambda);
    case 'shallow_mlp'
        [payload, fallbackUsed] = train_shallow_mlp_model(Xtrain, Ytrain, Wtrain, modelConfig.trainingOptions);
    case 'sequence_placeholder'
        payload = train_sequence_placeholder_model(Xtrain, Ytrain, Wtrain, modelConfig.trainingOptions);
        fallbackUsed = true;
    case 'ensemble_summary'
        [payload, fallbackUsed] = train_ensemble_summary_model(Xtrain, Ytrain, Wtrain, modelConfig.trainingOptions);
    otherwise
        error('Unsupported modelType: %s', modelConfig.modelType);
end

YhatTrain = denormalize_targets(predict_payload(payload, Xtrain), normalizationInfo.labels);
YhatVal = denormalize_targets(predict_payload(payload, Xval), normalizationInfo.labels);
YhatTest = denormalize_targets(predict_payload(payload, Xtest), normalizationInfo.labels);
YhatTrain(~isfinite(YhatTrain)) = 0;
YhatVal(~isfinite(YhatVal)) = 0;
YhatTest(~isfinite(YhatTest)) = 0;

identifierModel = struct();
identifierModel.modelType = payload.modelType;
identifierModel.config = targetConfig;
identifierModel.modelConfig = modelConfig;
identifierModel.targetNames = meta.targetNames;
identifierModel.featureInfo = meta.featureInfo;
identifierModel.normalizationInfo = normalizationInfo;
identifierModel.payload = payload;
identifierModel.trainingSetFeatures = Xnorm(trainIdx, :);
identifierModel.trainingSetTargets = Y(trainIdx, :);
identifierModel.trainingSetTargetsNormalized = Ytrain;
identifierModel.trainingSetMeta = meta.sampleMeta(trainIdx);

trainingReport = struct();
trainingReport.trainIdx = trainIdx;
trainingReport.valIdx = valIdx;
trainingReport.testIdx = testIdx;
trainingReport.fallbackUsed = fallbackUsed;
trainingReport.modelType = identifierModel.modelType;
trainingReport.targetNames = meta.targetNames;
trainingReport.sampleWeights = sampleWeights;
trainingReport.normalizationSummary = normalizationInfo.summary;
trainingReport.trainMae = mae(Y(trainIdx, :), YhatTrain);
trainingReport.trainRmse = rmse(Y(trainIdx, :), YhatTrain);
trainingReport.valMae = mae(Yval, YhatVal);
trainingReport.valRmse = rmse(Yval, YhatVal);
trainingReport.testMae = mae(Ytest, YhatTest);
trainingReport.testRmse = rmse(Ytest, YhatTest);
trainingReport.perChannelMetrics = build_channel_metrics(meta.targetNames, trainingReport.testMae, trainingReport.testRmse);
trainingReport.perCategoryMetrics = build_category_metrics(meta.sampleMeta(testIdx), Ytest, YhatTest);
trainingReport.Ytrue = Ytest;
trainingReport.Yhat = YhatTest;
trainingReport.validationPrediction = YhatVal;
trainingReport.validationTruth = Yval;
trainingReport.testSampleMeta = meta.sampleMeta(testIdx);
trainingReport.trainSampleMeta = meta.sampleMeta(trainIdx);
end

function [X, Y, meta] = dataset_to_xy(identifierDataset, identifierConfig)
n = numel(identifierDataset.samples);
X = [];
Y = [];
featureInfo = struct();
sampleMeta = repmat(struct('damageCategory', "", 'damageSeverityLevel', "", 'featureMode', "", 'modelType', "", 'flightConditionTag', ""), n, 1);

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
    sampleMeta(i).damageCategory = string(sample.damageCategory);
    sampleMeta(i).damageSeverityLevel = string(sample.damageSeverityLevel);
    sampleMeta(i).featureMode = string(identifierConfig.featureMode);
    sampleMeta(i).modelType = string(identifierConfig.primaryModelType);
    sampleMeta(i).flightConditionTag = string(sample.flightConditionTag);
end

X(~isfinite(X)) = 0;
Y(~isfinite(Y)) = 0;

meta = struct('featureInfo', featureInfo, 'targetNames', {targetNames}, 'sampleMeta', sampleMeta);
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
    featureParts = {};
    if isfield(featureData, 'summaryFeatures')
        featureParts{end + 1} = featureData.summaryFeatures(:); %#ok<AGROW>
    end
    if isfield(featureData, 'normalizedFeatures')
        featureParts{end + 1} = featureData.normalizedFeatures(:); %#ok<AGROW>
    end
    if isfield(featureData, 'sequenceFeatures')
        featureParts{end + 1} = featureData.sequenceFeatures(:); %#ok<AGROW>
    end
    if isfield(featureData, 'rawFeatures')
        featureParts{end + 1} = featureData.rawFeatures(:); %#ok<AGROW>
    end
    features = vertcat(featureParts{:}).';
else
    features = featureData(:).';
end
features(~isfinite(features)) = 0;
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

groups = strings(n, 1);
for i = 1:n
    if isfield(identifierDataset.samples(i), 'damageCategory')
        groups(i) = string(identifierDataset.samples(i).damageCategory);
    else
        groups(i) = "generic";
    end
end

trainIdx = [];
valIdx = [];
testIdx = [];
cats = unique(groups);
for i = 1:numel(cats)
    idx = find(groups == cats(i));
    idx = idx(randperm(numel(idx)));
    nTrain = max(1, floor(opts.trainFraction * numel(idx)));
    nVal = max(1, floor(opts.valFraction * numel(idx)));
    trainIdx = [trainIdx; idx(1:nTrain)]; %#ok<AGROW>
    valIdx = [valIdx; idx(nTrain + 1:min(nTrain + nVal, numel(idx)))]; %#ok<AGROW>
    testIdx = [testIdx; idx(min(nTrain + nVal + 1, numel(idx)):end)]; %#ok<AGROW>
end
if isempty(valIdx)
    valIdx = trainIdx;
end
if isempty(testIdx)
    testIdx = valIdx;
end
end

function weights = compute_sample_weights(identifierDataset, modeName)
n = numel(identifierDataset.samples);
weights = ones(n, 1);
if ~strcmpi(modeName, 'by_damage_category')
    return;
end
cats = strings(n, 1);
for i = 1:n
    cats(i) = string(identifierDataset.samples(i).damageCategory);
end
uniq = unique(cats);
for i = 1:numel(uniq)
    idx = find(cats == uniq(i));
    weights(idx) = n / max(numel(uniq) * numel(idx), 1);
end
weights = weights / mean(weights);
end

function [Xnorm, info] = normalize_block(X, trainIdx, modeName)
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

function Y = denormalize_targets(Ynorm, info)
switch lower(info.mode)
    case 'zscore'
        Y = Ynorm .* info.sigma + info.mu;
    otherwise
        Y = Ynorm;
end
end

function payload = train_ridge_model(X, Y, w, lambda)
W = diag(w(:));
I = eye(size(X, 2));
payload = struct('modelType', 'ridge');
payload.beta = pinv(X' * W * X + lambda * I) * (X' * W * Y);
payload.bias = zeros(1, size(Y, 2));
payload.trainingVariance = var(Y, 0, 1);
end

function [payload, fallbackUsed] = train_shallow_mlp_model(X, Y, w, opts)
fallbackUsed = false;
if exist('fitrnet', 'file') == 2
    models = cell(1, size(Y, 2));
    for j = 1:size(Y, 2)
        validIdx = all(isfinite(X), 2) & isfinite(Y(:, j));
        if nnz(validIdx) < 10
            payload = train_ridge_model(X, Y, w, opts.ridgeLambda);
            payload.modelType = 'ridge';
            fallbackUsed = true;
            return;
        end
        models{j} = fitrnet(X(validIdx, :), Y(validIdx, j), 'LayerSizes', opts.hiddenLayerSize, 'Activations', 'relu', 'Standardize', false, 'Weights', w(validIdx));
    end
    payload = struct('modelType', 'shallow_mlp', 'models', {models}, 'trainingVariance', var(Y, 0, 1));
else
    payload = train_ridge_model(X, Y, w, opts.ridgeLambda);
    payload.modelType = 'ridge';
    fallbackUsed = true;
end
end

function payload = train_sequence_placeholder_model(X, Y, w, opts)
% TODO: Replace with a real sequence model when the toolchain is ready.
payload = train_ridge_model(X, Y, w, opts.ridgeLambda);
payload.modelType = 'sequence_placeholder';
end

function [payload, fallbackUsed] = train_ensemble_summary_model(X, Y, w, opts)
ridgePayload = train_ridge_model(X, Y, w, opts.ridgeLambda);
[mlpPayload, fallbackUsed] = train_shallow_mlp_model(X, Y, w, opts);
payload = struct();
payload.modelType = 'ensemble_summary';
payload.members = {ridgePayload, mlpPayload};
payload.trainingVariance = var(Y, 0, 1);
end

function Yhat = predict_payload(payload, X)
switch lower(payload.modelType)
    case {'ridge', 'sequence_placeholder'}
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

function metrics = build_channel_metrics(targetNames, maeVals, rmseVals)
metrics = table(string(targetNames(:)), maeVals(:), rmseVals(:), ...
    'VariableNames', {'targetName', 'mae', 'rmse'});
end

function tbl = build_category_metrics(sampleMeta, Ytrue, Yhat)
cats = unique(string({sampleMeta.damageCategory}));
rows = struct('damageCategory', {}, 'etaTotalMae', {}, 'etaTotalRmse', {});
for i = 1:numel(cats)
    idx = strcmp(string({sampleMeta.damageCategory}), cats(i));
    err = Yhat(idx, end) - Ytrue(idx, end);
    rows(i).damageCategory = cats(i); %#ok<AGROW>
    rows(i).etaTotalMae = mean(abs(err)); %#ok<AGROW>
    rows(i).etaTotalRmse = sqrt(mean(err.^2)); %#ok<AGROW>
end
tbl = struct2table(rows);
end

function out = rmse(Ytrue, Yhat)
out = sqrt(mean((Yhat - Ytrue).^2, 1));
end

function out = mae(Ytrue, Yhat)
out = mean(abs(Yhat - Ytrue), 1);
end
