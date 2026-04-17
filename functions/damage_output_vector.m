function y = damage_output_vector(z)
%DAMAGE_OUTPUT_VECTOR Packed interface for Simulink interpreted function use.
%   z = [x(12); u(nu); theta_d(12)]

z = z(:);

if numel(z) < 28
    error('damage_output_vector expects at least 28 elements: x(12), u(4), theta_d(12).');
end

x = z(1:12);
u = z(13:16);
theta_d = z(17:28);

[deltaF_b_N, deltaM_b_Nm, eta_ctrl] = damage_injection_interface(x, u, theta_d);
y = [deltaF_b_N(:); deltaM_b_Nm(:); eta_ctrl(:)];
end
