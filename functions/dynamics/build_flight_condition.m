function flightCondition = build_flight_condition(currentState, controlInput)
%BUILD_FLIGHT_CONDITION Construct a lightweight flight condition structure.
%
%   flightCondition = build_flight_condition() returns a nominal struct
%   built from P.initial in the base workspace.
%   flightCondition = build_flight_condition(currentState, controlInput)
%   uses an explicit 12-element state vector and 4-element control vector.
%
%   The returned struct exposes airspeed, alpha, beta, dynamic pressure,
%   altitude, and the raw uvw / euler / pqr blocks. damageSeverity is
%   initialized to zero and is overwritten by callers as needed.
%
%   Requires P in the base workspace (loaded by scripts/init_project.m).

if nargin < 1 || isempty(currentState)
    Pcfg = get_project_params();
    currentState = [ ...
        Pcfg.initial.pned_m(:); ...
        Pcfg.initial.uvw_mps(:); ...
        Pcfg.initial.euler_rad(:); ...
        Pcfg.initial.pqr_rps(:)];
end

if nargin < 2 || isempty(controlInput)
    Pcfg = get_project_params();
    controlInput = Pcfg.control.trim(:);
end

currentState = reshape(currentState, [], 1);
controlInput = reshape(controlInput, [], 1);

if numel(currentState) < 12
    error('build_flight_condition expects a state vector with at least 12 elements.');
end

uvw = currentState(4:6);
euler = currentState(7:9);
pqr = currentState(10:12);

uBody = uvw(1);
vBody = uvw(2);
wBody = uvw(3);
airspeed = max(10.0, norm(uvw));
alpha = atan2(wBody, max(abs(uBody), 1.0e-3));
beta = asin(max(-0.99, min(0.99, vBody / airspeed)));

Pcfg = get_project_params();
rho = Pcfg.aero.rho0 * exp(-max(0, -currentState(3)) / 10000.0);

flightCondition = struct();
flightCondition.pned_m = currentState(1:3);
flightCondition.uvw_mps = uvw;
flightCondition.euler_rad = euler;
flightCondition.pqr_rps = pqr;
flightCondition.controlInput = controlInput;
flightCondition.altitude_m = -currentState(3);
flightCondition.airspeed_mps = airspeed;
flightCondition.alpha_rad = alpha;
flightCondition.beta_rad = beta;
flightCondition.dynamicPressure_Pa = 0.5 * rho * airspeed^2;
flightCondition.damageSeverity = 0.0;
end
