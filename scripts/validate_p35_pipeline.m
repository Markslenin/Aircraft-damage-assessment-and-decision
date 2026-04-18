function validationSummary = validate_p35_pipeline()
%VALIDATE_P35_PIPELINE Check the main P3.5 artifacts and print a summary.

rootDir = fileparts(fileparts(mfilename('fullpath')));
requiredFiles = { ...
    fullfile(rootDir, 'data', 'identifier_dataset_v3.mat'), ...
    fullfile(rootDir, 'results', 'identifier_hyperparam_sweep.mat'), ...
    fullfile(rootDir, 'results', 'error_breakdown.mat'), ...
    fullfile(rootDir, 'results', 'decision_sensitivity.mat'), ...
    fullfile(rootDir, 'results', 'decision_consistency_v2.mat')};

missingFiles = requiredFiles(~cellfun(@isfile, requiredFiles));
validationSummary = struct('missingFiles', {missingFiles});
if ~isempty(missingFiles)
    fprintf('Missing P3.5 artifacts:\n');
    fprintf('  %s\n', missingFiles{:});
    return;
end

D = load(requiredFiles{1}, 'identifierDataset');
H = load(requiredFiles{2}, 'sweepResult');
C = load(requiredFiles{5}, 'decisionConsistencyV2');

datasetOk = isfield(D.identifierDataset, 'samples') && isfield(D.identifierDataset.samples, 'damageCategory') && ...
    isfield(D.identifierDataset.samples, 'datasetVersion');

bestRow = H.sweepResult.summaryTable(1, :);
validationSummary.datasetOk = datasetOk;
validationSummary.bestModelConfig = sprintf('%s + %s + %s', bestRow.modelType, bestRow.featureMode, bestRow.residualFilterMode);
validationSummary.bestEtaTotalMae = bestRow.etaTotalMae;
validationSummary.bestDecisionMatchRate = bestRow.decisionMatchRate;
validationSummary.unsafeUndertriggerCount = C.decisionConsistencyV2.unsafeUndertriggerCount;

fprintf('P3.5 validation summary\n');
fprintf('Best model config: %s\n', validationSummary.bestModelConfig);
fprintf('Best eta_total MAE: %.4f\n', validationSummary.bestEtaTotalMae);
fprintf('Best decision match rate: %.2f%%\n', 100 * validationSummary.bestDecisionMatchRate);
fprintf('unsafe_undertrigger_count: %d\n', validationSummary.unsafeUndertriggerCount);
end
