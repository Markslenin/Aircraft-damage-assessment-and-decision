function modelConfig = get_identifier_model_config(modelType, featureMode)
%GET_IDENTIFIER_MODEL_CONFIG Return a pluggable identifier model config.

if nargin < 1 || isempty(modelType)
    modelType = 'ridge';
end
if nargin < 2 || isempty(featureMode)
    featureMode = 'summary_plus_residual_energy';
end

baseTargetConfig = get_identifier_target_config();

modelConfig = struct();
modelConfig.modelType = lower(modelType);
modelConfig.featureMode = featureMode;
modelConfig.normalizationMode = 'zscore';
modelConfig.trainingOptions = struct( ...
    'trainFraction', 0.6, ...
    'valFraction', 0.2, ...
    'ridgeLambda', 1.0, ...
    'hiddenLayerSize', 16, ...
    'maxEpochs', 200);
modelConfig.identifierTargetConfig = baseTargetConfig;
modelConfig.identifierTargetConfig.featureMode = featureMode;
modelConfig.identifierTargetConfig.primaryModelType = lower(modelType);
end
