function uCmd = decision_command_vector(theta_d)
%DECISION_COMMAND_VECTOR Simulink bridge for rule-based command selection.
%   Input:
%     theta_d - 12x1 damage vector
%   Output:
%     uCmd    - 4x1 command vector [de; da; dr; throttle]

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
