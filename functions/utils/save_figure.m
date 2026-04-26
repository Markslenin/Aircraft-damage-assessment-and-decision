function save_figure(fig, fullPath)
%SAVE_FIGURE Persist a figure to disk and close it, creating dirs if needed.
%
%   save_figure(fig, fullPath) ensures the parent directory of fullPath
%   exists (creating it with mkdir if needed), saves fig as PNG (or any
%   format inferred from the extension by saveas), then closes fig.
%
%   This collapses the recurring 3-line pattern:
%       if ~exist(figDir, 'dir'); mkdir(figDir); end
%       saveas(f, fullfile(figDir, name));
%       close(f);
%   into a single call.

parentDir = fileparts(fullPath);
if ~isempty(parentDir) && ~exist(parentDir, 'dir')
    mkdir(parentDir);
end
saveas(fig, fullPath);
close(fig);
end
