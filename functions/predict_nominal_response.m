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
    commandedInput = evalin('base', 'P.control.trim');
end
if nargin < 3 || isempty(dt)
    dt = 0.1;
end
if nargin < 4 || isempty(nominalParams)
    nominalParams = evalin('base', 'P');
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
angAccel = [fm(4) / inertiaDiag(1); fm(5) / inertiaDiag(2); fm(6) / inertiaDiag(3)];

predictedVel = uvw + dt * accelBody;
predictedAngRate = pqr + dt * angAccel;
predictedAttitude = euler + dt * pqr;
predictedPosition = currentState(1:3) + dt * predictedVel;
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
