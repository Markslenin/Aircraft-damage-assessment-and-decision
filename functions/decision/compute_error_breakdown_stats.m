function stats = compute_error_breakdown_stats(values, groupLabels)
%COMPUTE_ERROR_BREAKDOWN_STATS Aggregate MAE/RMSE by categorical grouping.

if nargin < 2
    groupLabels = strings(size(values, 1), 1);
end

groupLabels = string(groupLabels(:));
groups = unique(groupLabels);
stats = struct('group', {}, 'count', {}, 'mean', {}, 'mae', {}, 'rmse', {}, 'median', {});

for i = 1:numel(groups)
    idx = groupLabels == groups(i);
    v = values(idx, :);
    stats(i).group = char(groups(i)); %#ok<AGROW>
    stats(i).count = nnz(idx);
    stats(i).mean = mean(v, 1, 'omitnan');
    stats(i).mae = mean(abs(v), 1, 'omitnan');
    stats(i).rmse = sqrt(mean(v.^2, 1, 'omitnan'));
    stats(i).median = median(v, 1, 'omitnan');
end
end
