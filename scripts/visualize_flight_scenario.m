function vizResult = visualize_flight_scenario(scenarioResult)
%VISUALIZE_FLIGHT_SCENARIO Create presentation-friendly scenario figures.
%   Input:
%     scenarioResult with fields:
%       scenarioName, time, stateHist, etaTotalHist, confidenceHist, modeHist
%   Output:
%     vizResult struct containing figure handles and derived traces

if nargin < 1 || isempty(scenarioResult)
    error('scenarioResult is required.');
end

t = scenarioResult.time(:);
stateHist = scenarioResult.stateHist;
positionNED = stateHist(:, 1:3);
velocityBody = stateHist(:, 4:6);
speed = vecnorm(velocityBody, 2, 2);
altitude = -positionNED(:, 3);

etaTotalHist = ensure_hist(scenarioResult, 'etaTotalHist', numel(t), 1.0);
confidenceHist = ensure_hist(scenarioResult, 'confidenceHist', numel(t), 1.0);
modeHist = ensure_hist(scenarioResult, 'modeHist', numel(t), 0);
eventTimes = get_event_times(scenarioResult);

vizResult = struct();
vizResult.scenarioName = string(scenarioResult.scenarioName);
vizResult.figures = struct();

f1 = figure('Name', char(vizResult.scenarioName + " - 3D Trajectory"), 'Color', 'w');
plot3(positionNED(:, 2), positionNED(:, 1), altitude, 'LineWidth', 1.8, 'Color', [0.10 0.36 0.65]);
hold on;
mark_trajectory_event(t, positionNED, altitude, eventTimes.damageStartTime, [0.82 0.33 0.12], 'Damage');
mark_trajectory_event(t, positionNED, altitude, eventTimes.decisionTime, [0.19 0.24 0.72], 'Decision');
hold off;
grid on;
xlabel('East (m)');
ylabel('North (m)');
zlabel('Altitude (m)');
title(sprintf('3D Trajectory - %s', scenarioResult.scenarioName), 'Interpreter', 'none');
legend('Trajectory', 'Damage', 'Decision', 'Location', 'best');
view(42, 24);
vizResult.figures.trajectory3d = f1;

f2 = figure('Name', char(vizResult.scenarioName + " - Altitude"), 'Color', 'w');
plot(t, altitude, 'LineWidth', 1.8, 'Color', [0.82 0.33 0.12]);
add_timeline_events(eventTimes);
grid on;
xlabel('Time (s)');
ylabel('Altitude (m)');
title(sprintf('Altitude vs Time - %s', scenarioResult.scenarioName), 'Interpreter', 'none');
vizResult.figures.altitude = f2;

f3 = figure('Name', char(vizResult.scenarioName + " - Speed"), 'Color', 'w');
plot(t, speed, 'LineWidth', 1.8, 'Color', [0.14 0.58 0.36]);
add_timeline_events(eventTimes);
grid on;
xlabel('Time (s)');
ylabel('Speed (m/s)');
title(sprintf('Speed vs Time - %s', scenarioResult.scenarioName), 'Interpreter', 'none');
vizResult.figures.speed = f3;

f4 = figure('Name', char(vizResult.scenarioName + " - Assessment"), 'Color', 'w');
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;
plot(t, etaTotalHist, 'LineWidth', 1.8, 'Color', [0.19 0.24 0.72]);
add_timeline_events(eventTimes);
ylim([0 1.05]);
grid on;
ylabel('\eta_{total}');
title(sprintf('Assessment Trace - %s', scenarioResult.scenarioName), 'Interpreter', 'none');
nexttile;
plot(t, confidenceHist, 'LineWidth', 1.8, 'Color', [0.46 0.24 0.62]);
add_timeline_events(eventTimes);
ylim([0 1.05]);
grid on;
ylabel('Confidence');
nexttile;
stairs(t, modeHist, 'LineWidth', 1.8, 'Color', [0.56 0.12 0.12]);
add_timeline_events(eventTimes);
grid on;
xlabel('Time (s)');
ylabel('Mode Code');
yticks(0:5);
yticklabels({'NORM', 'STAB', 'RET', 'DIV', 'EGR', 'UNR'});
vizResult.figures.assessment = f4;

vizResult.traces = struct( ...
    'altitude', altitude, ...
    'speed', speed, ...
    'etaTotalHist', etaTotalHist, ...
    'confidenceHist', confidenceHist, ...
    'modeHist', modeHist, ...
    'eventTimes', eventTimes);
end

function y = ensure_hist(scenarioResult, fieldName, N, defaultValue)
if isfield(scenarioResult, fieldName) && ~isempty(scenarioResult.(fieldName))
    y = scenarioResult.(fieldName)(:);
else
    y = repmat(defaultValue, N, 1);
end
if numel(y) == 1
    y = repmat(y, N, 1);
elseif numel(y) > N
    y = y(1:N);
elseif numel(y) < N
    y(end + 1:N, 1) = y(end);
end
end

function eventTimes = get_event_times(scenarioResult)
eventTimes = struct('damageStartTime', [], 'decisionTime', []);
if isfield(scenarioResult, 'eventTimes') && ~isempty(scenarioResult.eventTimes)
    if isfield(scenarioResult.eventTimes, 'damageStartTime')
        eventTimes.damageStartTime = scenarioResult.eventTimes.damageStartTime;
    end
    if isfield(scenarioResult.eventTimes, 'decisionTime')
        eventTimes.decisionTime = scenarioResult.eventTimes.decisionTime;
    end
end
end

function mark_trajectory_event(t, positionNED, altitude, eventTime, markerColor, markerName)
if isempty(eventTime) || ~isfinite(eventTime)
    return;
end
[~, idx] = min(abs(t - eventTime));
scatter3(positionNED(idx, 2), positionNED(idx, 1), altitude(idx), 64, markerColor, ...
    'filled', 'DisplayName', markerName);
end

function add_timeline_events(eventTimes)
hold on;
if ~isempty(eventTimes.damageStartTime) && isfinite(eventTimes.damageStartTime)
    xline(eventTimes.damageStartTime, '--', 'Damage', 'Color', [0.82 0.33 0.12], ...
        'LabelVerticalAlignment', 'bottom');
end
if ~isempty(eventTimes.decisionTime) && isfinite(eventTimes.decisionTime)
    xline(eventTimes.decisionTime, '--', 'Decision', 'Color', [0.19 0.24 0.72], ...
        'LabelVerticalAlignment', 'top');
end
hold off;
end
