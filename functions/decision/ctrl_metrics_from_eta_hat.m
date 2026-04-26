function ctrlMetrics = ctrl_metrics_from_eta_hat(identifierOutput)
%CTRL_METRICS_FROM_ETA_HAT Convert eta estimates into ctrlMetrics struct.
%
%   ctrlMetrics = ctrl_metrics_from_eta_hat(identifierOutput) takes the
%   normalized eta-hat fields (eta_roll_hat / eta_pitch_hat / eta_yaw_hat /
%   eta_total_hat) emitted by run_damage_identifier and packs them into the
%   same struct shape produced by compute_control_authority_metrics, so
%   downstream decision logic does not need to branch on which path
%   (theta or eta) the identifier chose.
%
%   The 0.35 eta_total threshold and 0.15 per-axis floor used to set
%   is_controllable mirror those in compute_control_authority_metrics.

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
