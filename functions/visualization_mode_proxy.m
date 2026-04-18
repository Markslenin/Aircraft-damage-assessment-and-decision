function modeCode = visualization_mode_proxy(identifierVector)
%VISUALIZATION_MODE_PROXY Lightweight mode proxy for the visualization layer.
%   Input format:
%     [eta_roll; eta_pitch; eta_yaw; eta_total; confidence]

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
