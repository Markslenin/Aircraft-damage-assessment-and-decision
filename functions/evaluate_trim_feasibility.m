function trimInfo = evaluate_trim_feasibility(damageParams, damageEffects, ctrlMetrics, flightCondition)
%EVALUATE_TRIM_FEASIBILITY Rule-based trim feasibility assessment.

if nargin < 1 || isempty(damageParams)
    damageParams = parse_damage_vector(zeros(12, 1));
end

if nargin < 2 || isempty(damageEffects)
    damageEffects = map_damage_to_aero_effects(damageParams, zeros(12, 1), zeros(4, 1));
end

if nargin < 3 || isempty(ctrlMetrics)
    ctrlMetrics = compute_control_authority_metrics(damageParams, damageEffects, []);
end

if nargin < 4 || isempty(flightCondition)
    flightCondition = build_flight_condition();
elseif ~isstruct(flightCondition)
    flightCondition = build_flight_condition(flightCondition, zeros(4, 1));
end

riskScore = 0.0;

if damageEffects.thrustEffScale < 0.30 && ctrlMetrics.eta_pitch < 0.40
    riskScore = riskScore + 0.55;
end

if ctrlMetrics.eta_pitch < 0.30 || damageEffects.liftScale < 0.40
    riskScore = riskScore + 0.30;
end

if min(ctrlMetrics.eta_roll, ctrlMetrics.eta_yaw) < 0.25
    riskScore = riskScore + 0.20;
end

if damageEffects.dragScale > 1.60 || flightCondition.airspeed_mps < 24.0
    riskScore = riskScore + 0.20;
end

if ~ctrlMetrics.is_controllable
    riskScore = riskScore + 0.40;
end

riskScore = min(riskScore, 1.0);

if riskScore >= 0.85 || (~ctrlMetrics.is_controllable && ctrlMetrics.eta_pitch < 0.20)
    trimRiskLevel = 'CRITICAL';
    isTrimmable = false;
    recommendedMode = 'UNRECOVERABLE';
elseif riskScore >= 0.60
    trimRiskLevel = 'HIGH';
    isTrimmable = true;
    recommendedMode = 'STABILIZE';
elseif riskScore >= 0.35
    trimRiskLevel = 'MEDIUM';
    isTrimmable = true;
    recommendedMode = 'DIVERT';
else
    trimRiskLevel = 'LOW';
    isTrimmable = true;
    recommendedMode = 'RETURN';
end

if damageEffects.thrustEffScale < 0.20 && ctrlMetrics.eta_pitch < 0.30
    isTrimmable = false;
    trimRiskLevel = 'CRITICAL';
    recommendedMode = 'UNRECOVERABLE';
end

trimInfo = struct();
trimInfo.is_trimmable = isTrimmable;
trimInfo.trimRiskLevel = trimRiskLevel;
trimInfo.recommendedMode = recommendedMode;
trimInfo.riskScore = riskScore;
end
