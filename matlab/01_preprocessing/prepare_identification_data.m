function [data_est, data_val, data_all] = prepare_identification_data(csvFile)
%PREPARE_IDENTIFICATION_DATA Build chronological estimation/validation data.
%   The normalized historical dataset is used without changing its numerical
%   scaling. The expected sampling interval is 600 seconds.

if nargin < 1
    scriptDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(fileparts(scriptDir));
    csvFile = fullfile(repoRoot, 'data', 'processed', ...
        'normalized_identification_dataset.csv');
end

T = readtable(csvFile);
required = {'created_at','u_irrig','soil_frac','air_temp','humidity'};
assert(all(ismember(required, T.Properties.VariableNames)), ...
    'Dataset is missing one or more required columns.');

timestamps = datetime(T.created_at, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
[timestamps, order] = sort(timestamps);
T = T(order,:);

dt = seconds(diff(timestamps));
assert(~isempty(dt) && all(dt == dt(1)), ...
    'Dataset timestamps must be uniformly sampled.');
Ts = dt(1);
assert(Ts == 600, 'Expected the historical 600-second sampling interval.');

inputs = [T.u_irrig, T.air_temp, T.humidity];
output = T.soil_frac;
data_all = iddata(output, inputs, Ts, ...
    'InputName', {'Irrigation','AirTemperature','Humidity'}, ...
    'OutputName', {'SoilMoisture'});

splitIndex = floor(0.70 * height(T));
data_est = data_all(1:splitIndex);
data_val = data_all(splitIndex+1:end);
end

