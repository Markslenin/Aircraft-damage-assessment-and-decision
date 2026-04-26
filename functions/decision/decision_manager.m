function decisionOutput = decision_manager(ctrlMetrics, trimInfo, currentFlightCondition)
%DECISION_MANAGER Robust rule-based mission decision manager.

if nargin < 1 || isempty(ctrlMetrics)
    ctrlMetrics = compute_control_authority_metrics([], [], []);
end
if nargin < 2 || isempty(trimInfo)
    trimInfo = evaluate_trim_feasibility([], [], ctrlMetrics, []);
end
if nargin < 3 || isempty(currentFlightCondition)
    currentFlightCondition = build_flight_condition();
end

Pcfg = get_project_params();
if ~isfield(currentFlightCondition, 'damageSeverity')
    currentFlightCondition.damageSeverity = 0.0;
end
if ~isfield(currentFlightCondition, 'identifierConfidence')
    currentFlightCondition.identifierConfidence = 1.0;
end
if ~isfield(currentFlightCondition, 'identifierUncertainty')
    currentFlightCondition.identifierUncertainty = 0.0;
end
if ~isfield(currentFlightCondition, 'decisionConfig')
    currentFlightCondition.decisionConfig = Pcfg.decision;
end

cfg = currentFlightCondition.decisionConfig;
confidence = currentFlightCondition.identifierConfidence;
uncertainty = currentFlightCondition.identifierUncertainty;
damageSeverity = currentFlightCondition.damageSeverity;

etaVector = [ctrlMetrics.eta_roll, ctrlMetrics.eta_pitch, ctrlMetrics.eta_yaw, ctrlMetrics.eta_total];
if isfield(currentFlightCondition, 'etaHistory') && ~isempty(currentFlightCondition.etaHistory)
    etaHistory = currentFlightCondition.etaHistory;
else
    etaHistory = etaVector;
end
if cfg.etaSmoothingWindow > 1
    etaSmoothed = mean(etaHistory(max(1, end - cfg.etaSmoothingWindow + 1):end, :), 1);
else
    etaSmoothed = etaVector;
end
etaTotal = etaSmoothed(4);

if ~ctrlMetrics.is_controllable
    candidateMode = 'UNRECOVERABLE';
    commandType = 'EMERGENCY_RECOVERY';
    rationale = 'Residual control authority is below the controllability threshold.';
elseif ~trimInfo.is_trimmable
    if etaTotal >= cfg.egressThreshold
        candidateMode = 'EGRESS_PREP';
        commandType = 'ATTITUDE_HOLD_ESCAPE';
        rationale = 'Short-term stabilization remains possible but trim is not feasible.';
    else
        candidateMode = 'UNRECOVERABLE';
        commandType = 'EMERGENCY_RECOVERY';
        rationale = 'Trim feasibility is lost and total authority is insufficient.';
    end
elseif etaTotal >= cfg.returnThreshold && strcmp(trimInfo.trimRiskLevel, 'LOW') && damageSeverity < 0.05
    candidateMode = 'NORMAL';
    commandType = 'TRIM_FOLLOW';
    rationale = 'Residual authority is near nominal and trim risk is low.';
elseif etaTotal >= cfg.returnThreshold && any(strcmp(trimInfo.trimRiskLevel, {'LOW', 'MEDIUM'}))
    candidateMode = 'RETURN';
    commandType = 'RETURN_PROFILE';
    rationale = 'Vehicle remains controllable and trimmable with adequate total authority.';
elseif etaTotal >= cfg.divertThreshold
    if strcmp(trimInfo.trimRiskLevel, 'HIGH')
        candidateMode = 'STABILIZE';
        commandType = 'SAFE_HOLD';
        rationale = 'Stabilization is feasible but trim risk is elevated.';
    else
        candidateMode = 'DIVERT';
        commandType = 'DIVERT_PROFILE';
        rationale = 'Vehicle can remain airborne but should divert conservatively.';
    end
elseif etaTotal >= cfg.egressThreshold
    candidateMode = 'EGRESS_PREP';
    commandType = 'ATTITUDE_HOLD_ESCAPE';
    rationale = 'Only short-duration stabilization margin remains.';
else
    candidateMode = 'UNRECOVERABLE';
    commandType = 'EMERGENCY_RECOVERY';
    rationale = 'Residual total authority is too low for safe recovery planning.';
end

if cfg.confidenceGuardEnabled && (confidence < cfg.confidenceReturnMin || uncertainty > cfg.uncertaintyHigh)
    [candidateMode, commandType, rationale] = apply_confidence_guard(candidateMode, commandType, rationale);
end

previousMode = '';
previousModeDuration = inf;
if isfield(currentFlightCondition, 'previousDecisionMode')
    previousMode = upper(string(currentFlightCondition.previousDecisionMode));
end
if isfield(currentFlightCondition, 'previousModeDuration')
    previousModeDuration = currentFlightCondition.previousModeDuration;
end

finalMode = candidateMode;
if cfg.hysteresisEnabled && strlength(previousMode) > 0
    finalMode = apply_hysteresis(previousMode, candidateMode, etaTotal, cfg);
end
if ~strcmpi(finalMode, previousMode) && previousModeDuration < cfg.minModeDuration
    finalMode = char(previousMode);
    rationale = 'Mode change held by minimum-duration guard.';
end
commandType = mode_to_command(finalMode, commandType);

decisionOutput = struct();
decisionOutput.mode = finalMode;
decisionOutput.commandType = commandType;
decisionOutput.rationale = rationale;
decisionOutput.modeCode = mode_to_code(finalMode);
decisionOutput.identifierConfidence = confidence;
decisionOutput.identifierUncertainty = uncertainty;
decisionOutput.etaSmoothed = etaSmoothed;
decisionOutput.decisionMeta = struct( ...
    'candidateMode', candidateMode, ...
    'previousMode', char(previousMode), ...
    'previousModeDuration', previousModeDuration, ...
    'hysteresisEnabled', cfg.hysteresisEnabled, ...
    'confidenceGuardEnabled', cfg.confidenceGuardEnabled);
end

function [modeOut, commandType, rationale] = apply_confidence_guard(modeIn, commandTypeIn, rationaleIn)
modeOrder = {'NORMAL', 'RETURN', 'DIVERT', 'STABILIZE', 'EGRESS_PREP', 'UNRECOVERABLE'};
idx = find(strcmp(modeOrder, upper(modeIn)), 1, 'first');
idx = min(idx + 1, numel(modeOrder));
modeOut = modeOrder{idx};
commandType = mode_to_command(modeOut, commandTypeIn);
rationale = sprintf('%s Confidence guard applied.', rationaleIn);
end

function modeOut = apply_hysteresis(previousMode, candidateMode, etaTotal, cfg)
modeOut = candidateMode;
prev = char(previousMode);
if strcmpi(prev, candidateMode)
    return;
end
if is_more_aggressive(candidateMode, prev) && etaTotal < cfg.returnThreshold + 0.05
    modeOut = prev;
end
end

function tf = is_more_aggressive(modeA, modeB)
order = containers.Map( ...
    {'NORMAL', 'RETURN', 'DIVERT', 'STABILIZE', 'EGRESS_PREP', 'UNRECOVERABLE'}, ...
    [1 2 3 4 5 6]);
tf = order(upper(modeA)) < order(upper(modeB));
end

function commandType = mode_to_command(modeName, defaultCommand)
switch upper(modeName)
    case 'NORMAL'
        commandType = 'TRIM_FOLLOW';
    case 'RETURN'
        commandType = 'RETURN_PROFILE';
    case 'DIVERT'
        commandType = 'DIVERT_PROFILE';
    case 'STABILIZE'
        commandType = 'SAFE_HOLD';
    case 'EGRESS_PREP'
        commandType = 'ATTITUDE_HOLD_ESCAPE';
    case 'UNRECOVERABLE'
        commandType = 'EMERGENCY_RECOVERY';
    otherwise
        commandType = defaultCommand;
end
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
