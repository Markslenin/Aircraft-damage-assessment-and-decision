function identifierOutput = run_damage_identifier(identifierModel, features)
%RUN_DAMAGE_IDENTIFIER Run the trained identifier on one feature sample.

if size(features, 1) > 1
    features = features(1, :);
end

features = double(features(:).');
X = (features - identifierModel.mu) ./ identifierModel.sigma;

switch lower(identifierModel.modelType)
    case 'ridge'
        yhat = X * identifierModel.payload.beta + identifierModel.payload.bias;
    case 'mlp'
        yhat = zeros(1, numel(identifierModel.payload.models));
        for j = 1:numel(identifierModel.payload.models)
            yhat(j) = predict(identifierModel.payload.models{j}, X);
        end
    otherwise
        error('Unsupported identifier model type: %s', identifierModel.modelType);
end

yhat = max(min(yhat, 1.0), 0.0);

identifierOutput = struct();

if strcmpi(identifierModel.config.mode, 'theta')
    identifierOutput.theta_d_hat = yhat(:);
    identifierOutput.confidence = 0.5;
else
    identifierOutput.eta_roll_hat = yhat(1);
    identifierOutput.eta_pitch_hat = yhat(2);
    identifierOutput.eta_yaw_hat = yhat(3);
    identifierOutput.eta_total_hat = yhat(4);
    identifierOutput.confidence = exp(-norm((features - identifierModel.mu) ./ identifierModel.sigma) / sqrt(numel(features)));
end
end
