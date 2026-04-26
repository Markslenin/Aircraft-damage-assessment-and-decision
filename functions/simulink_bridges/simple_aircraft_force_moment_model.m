function y = simple_aircraft_force_moment_model(z)
%SIMPLE_AIRCRAFT_FORCE_MOMENT_MODEL Baseline force/moment model for P1.
%   z = [x(12); u_cmd(4); theta_d(12)]
%
% The actuator/propulsion path produces the nominal force and moment set
% with control/thrust effectiveness applied. Structural damage force/moment
% deltas are injected separately through damage_injection_interface.

z = z(:);

if numel(z) < 28
    error('simple_aircraft_force_moment_model expects 28 elements: x(12), u_cmd(4), theta_d(12).');
end

x = z(1:12);
u_cmd = z(13:16);
theta_d = z(17:28);

Pcfg = get_project_params();
damageParams = parse_damage_vector(theta_d);
damageEffects = map_damage_to_aero_effects(damageParams, x, u_cmd);

u_eff = u_cmd(:);
u_eff(1) = u_eff(1) * damageEffects.elevatorEffScale;
u_eff(2) = u_eff(2) * damageEffects.aileronEffScale;
u_eff(3) = u_eff(3) * damageEffects.rudderEffScale;
u_eff(4) = u_eff(4) * damageEffects.thrustEffScale;

flightCondition = build_flight_condition(x, u_eff);
uvw = flightCondition.uvw_mps;
euler = flightCondition.euler_rad;

uBody = uvw(1);
wBody = uvw(3);
alpha = flightCondition.alpha_rad;
beta = flightCondition.beta_rad;
V = flightCondition.airspeed_mps;

de = clamp(u_eff(1), -0.5, 0.5);
da = clamp(u_eff(2), -0.5, 0.5);
dr = clamp(u_eff(3), -0.5, 0.5);
throttle = clamp(u_eff(4), 0.0, 1.0);

qbar = flightCondition.dynamicPressure_Pa;
S = Pcfg.aircraft.wingArea;
b = Pcfg.aircraft.span;
cbar = Pcfg.aircraft.meanAerodynamicChord;

CL = Pcfg.aero.CL0 + Pcfg.aero.CLalpha * alpha + Pcfg.aero.CLde * de;
CD = Pcfg.aero.CD0 + Pcfg.aero.CDk * CL^2;
CY = Pcfg.aero.CYbeta * beta + 0.1 * dr;

L = qbar * S * CL;
D = qbar * S * CD;
Y = qbar * S * CY;
T = Pcfg.propulsion.maxThrustN * throttle;

phi = euler(1);
theta = euler(2);
g_b = Pcfg.aircraft.mass * Pcfg.environment.gravity * ...
    [-sin(theta); sin(phi) * cos(theta); cos(phi) * cos(theta)];

Fx = T - D * cos(alpha) + L * sin(alpha);
Fy = Y;
Fz = -L * cos(alpha) - D * sin(alpha);

Cl = Pcfg.aero.Cl_da * da;
Cm = Pcfg.aero.Cm0 + Pcfg.aero.Cmalpha * alpha + Pcfg.aero.Cmde * de;
Cn = Pcfg.aero.Cn_dr * dr;

Mx = qbar * S * b * Cl;
My = qbar * S * cbar * Cm;
Mz = qbar * S * b * Cn;

if ~isfinite(V)
    Fx = 0; Fy = 0; Fz = 0;
    Mx = 0; My = 0; Mz = 0;
end

F_b_N = [Fx; Fy; Fz] + g_b;
M_b_Nm = [Mx; My; Mz];

y = [F_b_N; M_b_Nm];
end
