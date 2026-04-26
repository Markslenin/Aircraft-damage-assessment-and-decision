function uCmd = decision_command_vector(theta_d)
%DECISION_COMMAND_VECTOR Simulink bridge for rule-based command selection.
%
%   Input:
%     theta_d - 12x1 damage vector (in [0, 1])
%   Output:
%     uCmd    - 4x1 command vector [de; da; dr; throttle]
%
%   Pulls a flight-condition-aware decision from decision_manager and
%   returns the canonical control command for the chosen mission mode.
%
%   Requires P in the base workspace (loaded by scripts/init_project.m);
%   the function reads it through get_project_params(). This is the
%   interpreted-MATLAB-Function used by the "DecisionBridge" Simulink block.

if nargin < 1 || isempty(theta_d)
    theta_d = zeros(12, 1);
end

Pcfg = get_project_params();
flightCondition = build_flight_condition();
damageParams = parse_damage_vector(theta_d);
damageEffects = map_damage_to_aero_effects(damageParams, [], Pcfg.control.trim);
flightCondition.damageSeverity = damageParams.severity.overall;
ctrlMetrics = compute_control_authority_metrics(damageParams, damageEffects, flightCondition);
trimInfo = evaluate_trim_feasibility(damageParams, damageEffects, ctrlMetrics, flightCondition);
decisionOutput = decision_manager(ctrlMetrics, trimInfo, flightCondition);

modeCommands = Pcfg.control.modeCommands;

switch upper(decisionOutput.mode)
    case 'NORMAL'
        uCmd = modeCommands.NORMAL;
    case 'STABILIZE'
        uCmd = modeCommands.STABILIZE;
    case 'RETURN'
        uCmd = modeCommands.RETURN;
    case 'DIVERT'
        uCmd = modeCommands.DIVERT;
    case 'EGRESS_PREP'
        uCmd = modeCommands.EGRESS_PREP;
    otherwise
        uCmd = modeCommands.UNRECOVERABLE;
end

uCmd = reshape(uCmd, 4, 1);
end
