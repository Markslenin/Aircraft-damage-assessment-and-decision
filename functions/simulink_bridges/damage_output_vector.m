function y = damage_output_vector(z)
%DAMAGE_OUTPUT_VECTOR Packed interface for Simulink interpreted function use.
%
%   y = damage_output_vector(z), with
%       z = [x(12); u(4); theta_d(12)]                (28 x 1, packed input)
%       y = [deltaF_b_N(3); deltaM_b_Nm(3); eta_ctrl(4)]  (10 x 1, packed output)
%
%   Wraps damage_injection_interface so the result fits a single
%   Interpreted MATLAB Function block. This is the function wired into
%   the "DamageMap" Simulink block.

z = z(:);

if numel(z) < 28
    error('damage_output_vector expects 28 elements: x(12), u(4), theta_d(12).');
end

x = z(1:12);
u = z(13:16);
theta_d = z(17:28);

[deltaF_b_N, deltaM_b_Nm, eta_ctrl] = damage_injection_interface(x, u, theta_d);
y = [deltaF_b_N(:); deltaM_b_Nm(:); eta_ctrl(:)];
end
