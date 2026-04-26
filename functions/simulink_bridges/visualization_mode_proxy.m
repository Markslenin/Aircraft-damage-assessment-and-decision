function modeCode = visualization_mode_proxy(identifierVector)
%VISUALIZATION_MODE_PROXY Lightweight mode proxy for the visualization layer.
%
%   modeCode = visualization_mode_proxy(identifierVector), with
%       identifierVector = [eta_roll; eta_pitch; eta_yaw; eta_total; confidence]
%
%   Returns a small integer code consumable by the visualization subsystem:
%       1 STABILIZE-like, 2 RETURN-like, 3 DIVERT-like,
%       4 EGRESS-like,    5 UNRECOVERABLE-like.
%
%   Low confidence (<0.45) shifts eta_total down by 0.10 before the
%   threshold check, so visualization de-escalates when the identifier
%   itself is uncertain. This is the function wired into the
%   "Visualization_Mode_Proxy" Simulink block.

if nargin < 1 || isempty(identifierVector)
    identifierVector = [1; 1; 1; 1; 1];
end

identifierVector = identifierVector(:);
etaTotal = identifierVector(min(4, numel(identifierVector)));
confidence = identifierVector(min(5, numel(identifierVector)));

if confidence < 0.45
    etaTotal = etaTotal - 0.10;
end

if etaTotal >= 0.85
    modeCode = 2; % RETURN-like
elseif etaTotal >= 0.60
    modeCode = 3; % DIVERT-like
elseif etaTotal >= 0.35
    modeCode = 1; % STABILIZE-like
elseif etaTotal >= 0.20
    modeCode = 4; % EGRESS-like
else
    modeCode = 5; % UNRECOVERABLE-like
end
end
