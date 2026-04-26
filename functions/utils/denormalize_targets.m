function Y = denormalize_targets(Ynorm, info)
%DENORMALIZE_TARGETS Reverse a label normalization recorded during training.
%
%   Y = denormalize_targets(Ynorm, info) takes a matrix of normalized
%   predictions and applies the inverse transform described by info.mode.
%   The supported modes mirror those produced by train_damage_identifier:
%       'zscore' : Y = Ynorm .* info.sigma + info.mu
%       'none' / unknown : Y = Ynorm
%
%   info is the struct stored under identifierModel.normalizationInfo.labels.

switch lower(info.mode)
    case 'zscore'
        Y = Ynorm .* info.sigma + info.mu;
    otherwise
        Y = Ynorm;
end
end
