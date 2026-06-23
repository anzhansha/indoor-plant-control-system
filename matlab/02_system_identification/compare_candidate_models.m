%COMPARE_CANDIDATE_MODELS Scripted comparison on the historical dataset.
% The output data are model-generated; validation is not an independent
% physical-plant experiment.

clear; clc; close all

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(scriptDir));
addpath(fullfile(repoRoot, 'matlab', '01_preprocessing'));
[data_est, data_val] = prepare_identification_data();

models = struct();
models.ARX_441 = arx(data_est, [4, 4 4 4, 1 1 1]);
models.ARMAX_221 = armax(data_est, [2, 2 2 2, 2, 1 1 1]);
models.OE_22 = oe(data_est, [2 2 2, 2 2 2, 1 1 1]);

try
    models.BJ_2222 = bj(data_est, ...
        [2 2 2, 2, 2, 2 2 2, 1 1 1]);
catch exception
    warning('BJ estimation was skipped: %s', exception.message);
end

models.N4SID_3 = n4sid(data_est, 3, 'Focus', 'simulation');

names = fieldnames(models);
fitPercent = zeros(numel(names),1);
fpeValue = zeros(numel(names),1);
mseValue = zeros(numel(names),1);

for index = 1:numel(names)
    model = models.(names{index});
    [~, fit] = compare(data_val, model);
    fitPercent(index) = fit(1);
    fpeValue(index) = fpe(model);
    mseValue(index) = model.Report.Fit.MSE;
end

comparison = table(string(names), fitPercent, fpeValue, mseValue, ...
    'VariableNames', {'Model','ValidationFitPercent','FPE','EstimationMSE'});
disp(comparison)

tablesDir = fullfile(repoRoot, 'results', 'tables');
modelsDir = fullfile(repoRoot, 'results', 'models');
if ~exist(tablesDir, 'dir'), mkdir(tablesDir); end
if ~exist(modelsDir, 'dir'), mkdir(modelsDir); end
writetable(comparison, fullfile(tablesDir, 'model_comparison.csv'));

selected_model = models.N4SID_3; %#ok<NASGU>
save(fullfile(modelsDir, 'selected_n4sid_3state_reproduced.mat'), ...
    'selected_model', 'comparison');

figure('Name', 'Selected N4SID validation');
compare(data_val, selected_model);
figure('Name', 'Selected N4SID residuals');
resid(data_val, selected_model);

