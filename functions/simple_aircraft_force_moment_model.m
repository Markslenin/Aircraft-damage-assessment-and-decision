function y = simple_aircraft_force_moment_model(z)
%SIMPLE_AIRCRAFT_FORCE_MOMENT_MODEL Baseline fixed-wing force/moment placeholder.
%   z = [x(12); u_cmd(4); eta_ctrl(4)]

z = z(:);

if numel(z) < 20
    error('simple_aircraft_force_moment_model expects 20 elements: x(12), u_cmd(4), eta_ctrl(4).');
end

x = z(1:12);
u_cmd = z(13:16);
eta_ctrl = z(17:20);
Pcfg = evalin('base', 'P');

u_eff = u_cmd(:) .* eta_ctrl(:);

uvw = x(4:6);
euler = x(7:9);

uBody = uvw(1);
vBody = uvw(2);
wBody = uvw(3);
V = max(10.0, norm(uvw));
alpha = atan2(wBody, max(abs(uBody), 1.0));
beta = asin(max(-0.99, min(0.99, vBody / V)));

de = sat(u_eff(1), -0.5, 0.5);
da = sat(u_eff(2), -0.5, 0.5);
dr = sat(u_eff(3), -0.5, 0.5);
throttle = sat(u_eff(4), 0.0, 1.0);

rho = Pcfg.aero.rho0;
qbar = 0.5 * rho * V^2;
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

F_b_N = [Fx; Fy; Fz] + g_b;
M_b_Nm = [Mx; My; Mz];

y = [F_b_N; M_b_Nm];
end

function y = sat(x, lo, hi)
y = min(max(x, lo), hi);
end
