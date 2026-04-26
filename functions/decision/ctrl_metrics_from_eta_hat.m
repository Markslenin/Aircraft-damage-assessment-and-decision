function ctrlMetrics = ctrl_metrics_from_eta_hat(identifierOutput)
%CTRL_METRICS_FROM_ETA_HAT Convert eta estimates into ctrlMetrics struct.

etaRoll = clamp(identifierOutput.eta_roll_hat, 0.0, 1.0);
etaPitch = clamp(identifierOutput.eta_pitch_hat, 0.0, 1.0);
etaYaw = clamp(identifierOutput.eta_yaw_hat, 0.0, 1.0);
etaTotal = clamp(identifierOutput.eta_total_hat, 0.0, 1.0);

ctrlMetrics = struct();
ctrlMetrics.eta_roll = etaRoll;
ctrlMetrics.eta_pitch = etaPitch;
ctrlMetrics.eta_yaw = etaYaw;
ctrlMetrics.eta_total = etaTotal;
ctrlMetrics.is_controllable = etaTotal >= 0.35 && min([etaRoll, etaPitch, etaYaw]) >= 0.15;
ctrlMetrics.weights = struct('roll', 0.35, 'pitch', 0.40, 'yaw', 0.25);
ctrlMetrics.biasPenalty = struct('roll', 0.0, 'pitch', 0.0, 'yaw', 0.0);
end
