function damageParams = parse_damage_vector(theta_d)
%PARSE_DAMAGE_VECTOR Convert 12x1 damage vector into a named structure.
%   theta_d uses the following order, each element in [0, 1]:
%   1  left_inner_wing
%   2  left_outer_wing
%   3  right_inner_wing
%   4  right_outer_wing
%   5  left_horizontal_tail
%   6  right_horizontal_tail
%   7  vertical_tail
%   8  left_aileron_eff
%   9  right_aileron_eff
%   10 elevator_eff
%   11 rudder_eff
%   12 thrust_eff

if nargin < 1 || isempty(theta_d)
    theta_d = zeros(12, 1);
end

theta_d = reshape(theta_d, [], 1);

if numel(theta_d) ~= 12
    error('parse_damage_vector expects a 12x1 damage vector.');
end

theta_d = min(max(theta_d, 0), 1);

damageParams = struct();
damageParams.theta_d = theta_d;

damageParams.left_inner_wing = theta_d(1);
damageParams.left_outer_wing = theta_d(2);
damageParams.right_inner_wing = theta_d(3);
damageParams.right_outer_wing = theta_d(4);
damageParams.left_horizontal_tail = theta_d(5);
damageParams.right_horizontal_tail = theta_d(6);
damageParams.vertical_tail = theta_d(7);
damageParams.left_aileron_eff = theta_d(8);
damageParams.right_aileron_eff = theta_d(9);
damageParams.elevator_eff = theta_d(10);
damageParams.rudder_eff = theta_d(11);
damageParams.thrust_eff = theta_d(12);

damageParams.wingDamage = struct( ...
    'left', mean(theta_d(1:2)), ...
    'right', mean(theta_d(3:4)), ...
    'total', mean(theta_d(1:4)), ...
    'asymmetry', mean(theta_d(3:4)) - mean(theta_d(1:2)));

damageParams.tailDamage = struct( ...
    'horizontal', mean(theta_d(5:6)), ...
    'vertical', theta_d(7), ...
    'horizontalAsymmetry', theta_d(6) - theta_d(5));

damageParams.controlEff = struct( ...
    'aileronLeft', 1 - theta_d(8), ...
    'aileronRight', 1 - theta_d(9), ...
    'aileronMean', 1 - mean(theta_d(8:9)), ...
    'elevator', 1 - theta_d(10), ...
    'rudder', 1 - theta_d(11), ...
    'thrust', 1 - theta_d(12));

damageParams.severity = struct( ...
    'structural', mean(theta_d(1:7)), ...
    'control', mean(theta_d(8:12)), ...
    'overall', mean(theta_d));
end
