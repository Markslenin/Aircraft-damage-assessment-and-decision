function decisionOutput = decision_manager(ctrlMetrics, trimInfo, currentFlightCondition)
%DECISION_MANAGER Rule-based mission decision manager for damaged aircraft.

if nargin < 1 || isempty(ctrlMetrics)
    ctrlMetrics = compute_control_authority_metrics([], [], []);
end

if nargin < 2 || isempty(trimInfo)
    trimInfo = evaluate_trim_feasibility([], [], ctrlMetrics, []);
end

if nargin < 3 || isempty(currentFlightCondition)
    currentFlightCondition = build_flight_condition();
end

if ~isfield(currentFlightCondition, 'damageSeverity')
    currentFlightCondition.damageSeverity = 0.0;
end

etaTotal = ctrlMetrics.eta_total;
damageSeverity = currentFlightCondition.damageSeverity;

if ~ctrlMetrics.is_controllable
    mode = 'UNRECOVERABLE';
    commandType = 'EMERGENCY_RECOVERY';
    rationale = 'Residual control authority is below the minimum controllability threshold.';
elseif ~trimInfo.is_trimmable
    if etaTotal >= 0.30
        mode = 'EGRESS_PREP';
        commandType = 'ATTITUDE_HOLD_ESCAPE';
        rationale = 'Short-term stabilization is possible, but sustained trim is not feasible.';
    else
        mode = 'UNRECOVERABLE';
        commandType = 'EMERGENCY_RECOVERY';
        rationale = 'Neither controllability nor trim feasibility is sufficient for mission continuation.';
    end
elseif etaTotal >= 0.90 && strcmp(trimInfo.trimRiskLevel, 'LOW') && damageSeverity < 0.05
    mode = 'NORMAL';
    commandType = 'TRIM_FOLLOW';
    rationale = 'Damage severity is negligible and residual authority is near nominal.';
elseif etaTotal >= 0.70 && any(strcmp(trimInfo.trimRiskLevel, {'LOW', 'MEDIUM'}))
    mode = 'RETURN';
    commandType = 'RETURN_PROFILE';
    rationale = 'Vehicle remains controllable and trimmable with adequate total authority.';
elseif etaTotal >= 0.50
    if strcmp(trimInfo.trimRiskLevel, 'HIGH')
        mode = 'STABILIZE';
        commandType = 'SAFE_HOLD';
        rationale = 'Residual authority supports stabilization, but trim risk is elevated.';
    else
        mode = 'DIVERT';
        commandType = 'DIVERT_PROFILE';
        rationale = 'Vehicle can continue flight, but should divert to a lower-risk recovery option.';
    end
elseif etaTotal >= 0.30
    mode = 'EGRESS_PREP';
    commandType = 'ATTITUDE_HOLD_ESCAPE';
    rationale = 'Only limited short-duration stabilization margin remains.';
else
    mode = 'UNRECOVERABLE';
    commandType = 'EMERGENCY_RECOVERY';
    rationale = 'Residual total authority is too low for safe recovery planning.';
end

decisionOutput = struct();
decisionOutput.mode = mode;
decisionOutput.commandType = commandType;
decisionOutput.rationale = rationale;
decisionOutput.modeCode = mode_to_code(mode);
end

function code = mode_to_code(mode)
switch upper(mode)
    case 'NORMAL'
        code = 0;
    case 'STABILIZE'
        code = 1;
    case 'RETURN'
        code = 2;
    case 'DIVERT'
        code = 3;
    case 'EGRESS_PREP'
        code = 4;
    otherwise
        code = 5;
end
end
