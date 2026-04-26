function nominalPrediction = predict_nominal_response(currentState, commandedInput, dt, nominalParams)
%PREDICT_NOMINAL_RESPONSE Unified nominal predictor for residual generation.
%   This is a lightweight engineering predictor built around the simplified
%   fixed-wing model. It is intended to provide more stable residuals than
%   direct differencing, while remaining easy to replace later by EKF/UKF,
%   MHE, or a higher-fidelity observer.

if nargin < 1 || isempty(currentState)
    currentState = build_flight_condition().pned_m;
end
if nargin < 2 || isempty(commandedInput)
    Pcfg = get_project_params();
    commandedInput = Pcfg.control.trim;
end
if nargin < 3 || isempty(dt)
    dt = 0.1;
end
if nargin < 4 || isempty(nominalParams)
    nominalParams = get_project_params();
end

currentState = reshape(currentState, [], 1);
commandedInput = reshape(commandedInput, [], 1);

if numel(currentState) < 12
    Pcfg = nominalParams;
    currentState = [ ...
        Pcfg.initial.pned_m(:); ...
        Pcfg.initial.uvw_mps(:); ...
        Pcfg.initial.euler_rad(:); ...
        Pcfg.initial.pqr_rps(:)];
end

damageFreeTheta = zeros(12, 1);
fm = simple_aircraft_force_moment_model([currentState; commandedInput; damageFreeTheta]);

mass = nominalParams.aircraft.mass;
inertiaDiag = diag(nominalParams.aircraft.inertia);

uvw = currentState(4:6);
euler = currentState(7:9);
pqr = currentState(10:12);

accelBody = fm(1:3) / mass - cross(pqr, uvw);
accelBody = clamp(accelBody, -60.0, 60.0);
angAccel = [fm(4) / inertiaDiag(1); fm(5) / inertiaDiag(2); fm(6) / inertiaDiag(3)];
angAccel = clamp(angAccel, -4.0, 4.0);

predictedVel = uvw + dt * accelBody;
speed = norm(predictedVel);
if speed > 120.0
    predictedVel = predictedVel * (120.0 / speed);
end
predictedAngRate = pqr + dt * angAccel;
predictedAngRate = clamp(predictedAngRate, -1.5, 1.5);
predictedAttitude = euler + dt * euler_rate_from_body_rates(euler, pqr);
predictedAttitude(1) = wrapToPiLocal(predictedAttitude(1));
predictedAttitude(2) = min(max(predictedAttitude(2), deg2rad(-75)), deg2rad(75));
predictedAttitude(3) = wrapToPiLocal(predictedAttitude(3));

velNed = body_to_ned(euler, predictedVel);
predictedPosition = currentState(1:3) + dt * velNed;
predictedState = [predictedPosition; predictedVel; predictedAttitude; predictedAngRate];

nominalPrediction = struct();
nominalPrediction.predictedVel = predictedVel;
nominalPrediction.predictedAngRate = predictedAngRate;
nominalPrediction.predictedAttitude = predictedAttitude;
nominalPrediction.predictedAccel = accelBody;
nominalPrediction.predictedState = predictedState;
nominalPrediction.stateHist = predictedState.';
nominalPrediction.predictedAccelHist = accelBody.';
nominalPrediction.controlHist = commandedInput.';
nominalPrediction.dt = dt;
nominalPrediction.predictorName = 'simple_airframe_nominal_predictor';
end

function ned = body_to_ned(euler, body)
phi = euler(1);
theta = euler(2);
psi = euler(3);
cphi = cos(phi); sphi = sin(phi);
cth = cos(theta); sth = sin(theta);
cpsi = cos(psi); spsi = sin(psi);

R_nb = [ ...
    cth*cpsi, sphi*sth*cpsi - cphi*spsi, cphi*sth*cpsi + sphi*spsi; ...
    cth*spsi, sphi*sth*spsi + cphi*cpsi, cphi*sth*spsi - sphi*cpsi; ...
    -sth,     sphi*cth,                  cphi*cth];
ned = R_nb * body(:);
end

function eulerRate = euler_rate_from_body_rates(euler, pqr)
phi = euler(1);
theta = min(max(euler(2), deg2rad(-80)), deg2rad(80));
p = pqr(1);
q = pqr(2);
r = pqr(3);
eulerRate = [ ...
    p + tan(theta) * (q * sin(phi) + r * cos(phi)); ...
    q * cos(phi) - r * sin(phi); ...
    (q * sin(phi) + r * cos(phi)) / max(cos(theta), 1.0e-3)];
end

function angle = wrapToPiLocal(angle)
angle = mod(angle + pi, 2*pi) - pi;
end
