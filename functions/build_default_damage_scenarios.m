function defs = build_default_damage_scenarios()
%BUILD_DEFAULT_DAMAGE_SCENARIOS Shared scenario set for P1/P2 scripts.

severities = [0.2, 0.5, 0.8];
defs = struct('scenarioType', {}, 'severity', {}, 'theta_d', {});
idx = 0;

for sev = severities
    idx = idx + 1;
    defs(idx) = make_def('wing', sev, [sev; sev; 0; 0; zeros(8, 1)]);
    idx = idx + 1;
    defs(idx) = make_def('tail', sev, [zeros(4, 1); sev; sev; sev; zeros(5, 1)]);
    idx = idx + 1;
    defs(idx) = make_def('control', sev, [zeros(7, 1); sev; sev; sev; sev; 0]);
    idx = idx + 1;
    defs(idx) = make_def('thrust', sev, [zeros(11, 1); sev]);
    idx = idx + 1;
    defs(idx) = make_def('compound', sev, [ ...
        0.7 * sev; sev; 0.2 * sev; 0.5 * sev; ...
        0.3 * sev; 0.5 * sev; 0.4 * sev; ...
        0.8 * sev; 0.6 * sev; 0.4 * sev; 0.5 * sev; 0.7 * sev]);
end
end

function def = make_def(typeName, severity, theta_d)
def = struct('scenarioType', typeName, 'severity', severity, 'theta_d', min(max(theta_d(:), 0), 1));
end
