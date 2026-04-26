function modelConfig = get_identifier_model_config(modelType, featureMode, varargin)
%GET_IDENTIFIER_MODEL_CONFIG Return an identifier training/inference config.

if nargin < 1 || isempty(modelType)
    modelType = 'ridge';
end
if nargin < 2 || isempty(featureMode)
    featureMode = 'normalized_summary';
end

baseTargetConfig = get_identifier_target_config();

modelConfig = struct();
modelConfig.modelType = lower(modelType);
modelConfig.featureMode = featureMode;
modelConfig.normalizationMode = 'zscore';
modelConfig.labelNormalizationMode = 'zscore';
modelConfig.trainingOptions = struct( ...
    'trainFraction', 0.6, ...
    'valFraction', 0.2, ...
    'ridgeLambda', 1.0, ...
    'hiddenLayerSize', 24, ...
    'maxEpochs', 250, ...
    'sampleWeightingMode', 'by_damage_category', ...
    'stratifyBy', 'damageCategory', ...
    'ensembleMemberTypes', {{'ridge', 'shallow_mlp'}});

switch modelConfig.modelType
    case 'ridge'
        modelConfig.normalizationMode = 'zscore';
    case 'shallow_mlp'
        modelConfig.normalizationMode = 'zscore';
        modelConfig.trainingOptions.hiddenLayerSize = 32;
    case 'ensemble_summary'
        modelConfig.normalizationMode = 'zscore';
        modelConfig.trainingOptions.hiddenLayerSize = 20;
    case 'sequence_placeholder'
        modelConfig.normalizationMode = 'zscore';
    otherwise
        error('Unsupported modelType: %s', modelType);
end

for i = 1:2:numel(varargin)
    modelConfig.(varargin{i}) = varargin{i + 1};
end

modelConfig.identifierTargetConfig = baseTargetConfig;
modelConfig.identifierTargetConfig.featureMode = featureMode;
modelConfig.identifierTargetConfig.primaryModelType = modelConfig.modelType;
if isfield(modelConfig, 'sequenceLength')
    modelConfig.identifierTargetConfig.sequenceLength = modelConfig.sequenceLength;
end
if isfield(modelConfig, 'residualFilterMode')
    modelConfig.identifierTargetConfig.residualFilterMode = modelConfig.residualFilterMode;
end
if isfield(modelConfig, 'residualWindowLength')
    modelConfig.identifierTargetConfig.residualWindowLength = modelConfig.residualWindowLength;
end
end
