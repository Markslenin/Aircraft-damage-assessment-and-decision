function severity = scenario_damage_severity(scenarioInfo, fallbackSeverity)
%SCENARIO_DAMAGE_SEVERITY Read severity from scenarioInfo with bounded fallback.
%
%   severity = scenario_damage_severity(scenarioInfo, fallbackSeverity) returns
%   scenarioInfo.severity when present and non-empty, otherwise fallbackSeverity.
%   The result is clamped to [0, 1].

severity = fallbackSeverity;
if isstruct(scenarioInfo) && isfield(scenarioInfo, 'severity') && ~isempty(scenarioInfo.severity)
    severity = scenarioInfo.severity;
end
severity = clamp(severity, 0.0, 1.0);
end
