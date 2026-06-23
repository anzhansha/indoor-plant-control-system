% Historical constrained LQR+I+Kalman simulation (formerly f_try47_lqr.m).
% Numerical assumptions are preserved; see docs/limitations.md before use.

clear; clc; close all

%% 1) Недельный план полива (мл/неделя) и длительность
W        = [350, 450, 550, 650, 750];  % объёмы для 5 недель
D        = 35;                        % дней = 5 недель
Ts       = 60;                        % шаг дискретизации в секундах
stepsDay = 86400 / Ts;
N        = D * stepsDay;
t_h      = (0:N-1)' * Ts/3600;        % время в часах

%% 2) Дискретизация модели
scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(scriptDir));
modelFile = fullfile(repoRoot, 'results', 'models', ...
    'controller_plant_model_corrected.mat');
load(modelFile, 'Gd_corrected');
Gc    = d2c(Gd_corrected,'zoh');
Gd    = c2d(Gc,Ts,'zoh');
[A,Bfull,C,~] = ssdata(Gd);
B1    = Bfull(:,1);
m     = size(A,1);

%% 3) Проектирование LQR + интегратор
Qx   = diag([10, ones(1,m-1)]);
Qw   = 0.05;
Qe   = blkdiag(Qx,Qw);
Ru   = 200;
Aaug = [A, zeros(m,1); -C, 1];
Baug = [B1; 0];
[Kfull,~,~] = dlqr(Aaug,Baug,Qe,Ru);
Kx   = Kfull(:,1:m);
Ki   = Kfull(:,m+1);
Nbar = 1/(C * ((eye(m)-A + B1*Kx)\B1));

%% 3.5) Печать LQR‐параметров и собственных чисел в командное окно

% 3.5.1) Вычислим замкнутую матрицу A_cl (дискретная) для аугментированной системы:
Acl = Aaug - Baug*Kfull;

% 3.5.2) Найдём её собственные числа:
eig_cl = eig(Acl);

fprintf('\n=== LQR DESIGN INFORMATION ===\n');
fprintf('Shape of Aaug:  %d×%d   |   shape of Baug:  %d×1\n', size(Aaug,1), size(Aaug,2), size(Baug,1));
fprintf('Qe (augmented) =\n');   disp(Qe);
fprintf('Ru = %.4f\n\n', Ru);

fprintf('Kfull (augmented) =\n'); disp(Kfull);
fprintf('  -> Kx  = [ %s ]  (size %d×%d)\n', ...
    num2str(Kx(:).','%.4f '), size(Kx,1), size(Kx,2));
fprintf('  -> Ki  = %.6f\n', Ki);
fprintf('Nbar     = %.6f\n\n', Nbar);

fprintf('Closed‐loop eigenvalues of (Aaug - Baug*Kfull):\n');
disp(eig_cl);

% Если нужно, можно показать модули (если в пределах единицы):
fprintf(' |eig| of closed‐loop (should be < 1 for stability):\n');
disp(abs(eig_cl));

%% 4) Калман‐фильтр
Qkf = 1e-6 * eye(m);
Rkf = 1e-4;
[~,L,~] = kalman(ss(A,[B1 eye(m)],C,0,Ts), Qkf, Rkf);

%% 5) Кусочно‐линейный сетпоинт (сниженный)
sp_breaks = [0.20, 0.22, 0.25, 0.28, 0.30, 0.30];
get_sp = @(d) ...
  (1 - rem(d-1,7)/7) * sp_breaks(min(ceil(d/7),5)) + ...
   (  rem(d-1,7)/7 ) * sp_breaks(min(ceil(d/7)+1,6));

%% 6) Инициализация логов и состояний
y        = zeros(N,1);
u        = zeros(N,1);
volDaily = zeros(D,1);
onDaily  = zeros(D,1);
err      = zeros(N,1);

u_raw_hist  = zeros(N,1);
xhat_hist   = zeros(m,N);
x_hist      = zeros(m,N);

xhat = zeros(m,1);
x    = zeros(m,1);
w    = 0;

%% 7) Основной цикл
for k = 1:N
  day = ceil(k/stepsDay);
  
  % 7.1) Ежедневный бюджет
  wk   = min(ceil(day/7),5);
  Vmax = W(wk) / 7;              
  if mod(k-1,stepsDay)==0
    remBud = Vmax;
  end
  
  % 7.2) Динамический сетпоинт
  sp   = get_sp(day);
  hyst = 0.005;
  y_low  = sp - hyst;
  y_high = sp + hyst;
  
  % 7.3) Измерение + Калман
  y(k) = C * x;
  if k > 1
    xhat = A*xhat + B1*u(k-1) + L*(y(k) - C*xhat);
  end
  
  % 7.4) Интегратор
  w = w + Ts * (sp - y(k));
  
  % 7.5) LQR+I
  u_raw = -Kx*xhat - Ki*w + Nbar*sp;
  u_raw_hist(k) = u_raw;
  
  % 7.6) Bang–bang + гистерезис
  if      y(k) < y_low
    duty0 = min(max(u_raw,0),1);
  elseif  y(k) > y_high
    duty0 = 0; w = 0;
  else
    duty0 = u(max(k-1,1));
  end
  
  % 7.7) Ограничение бюджета
  instVol = duty0 * (1.2/60/1000) * Ts * 1000;  % мЛ за шаг
  if instVol > remBud
    duty   = 0;
    instVol= 0;
  else
    duty   = duty0;
  end
  remBud = remBud - instVol;
  
  % 7.8) Обновление состояния
  u(k) = duty;
  x    = A*x + B1 * duty;
  
  x_hist(:,k)   = x;
  xhat_hist(:,k)= xhat;
  
  % 7.9) Логирование
  volDaily(day) = volDaily(day) + instVol;
  onDaily(day)  = onDaily(day)  + duty * Ts/3600;
  err(k)        = sp - y(k);
end

%% 8) Метрики производительности
IAE        = sum(abs(err)) * Ts;
totalWater = sum(volDaily);
WUE        = IAE / totalWater;
fprintf('\n=== PERFORMANCE METRICS ===\n');
fprintf('Total water used:      %.1f mL\n', totalWater);
fprintf('Integral Abs. Error:   %.2f moisture·s\n', IAE);
fprintf('Water-use efficiency:  %.3f moisture·s per mL\n\n', WUE);

%% 9) Анализ импульсов
durs = diff([0; u; 0]);
starts = find(durs==1);
ends   = find(durs==-1) - 1;
dur_s  = (ends - starts + 1) * Ts;
cyclesDay = histcounts(starts, (0:stepsDay:D*stepsDay)+eps);

%% 10) Вывод и графики

% (1) Moisture vs. setpoint
figure(1);
plot(t_h, y, 'b','LineWidth',1.2); hold on;
plot(t_h, arrayfun(@(k) get_sp(ceil(k/stepsDay)), 1:N), 'r--','LineWidth',1.2);
xlabel('Time (h)'); ylabel('Soil Moisture'); 
title('Moisture vs. Reduced Piecewise SP'); grid on;

% (2) Daily Water & Pump ON-time
figure(2);
yyaxis left
bar(1:D, volDaily);
ylabel('Water (mL/day)');
yyaxis right
plot(1:D, onDaily, '-ok','LineWidth',1.2);
ylabel('Pump ON-time (h/day)');
xlabel('Day');
title('Daily Water & Pump ON-time');
grid on;

% (3) Histogram of ON durations
figure(3);
histogram(dur_s,20);
xlabel('ON duration (s)'); ylabel('Count');
title('Pump ON Durations'); grid on;

% (4) Pump Cycles per Day
figure(4);
bar(1:D, cyclesDay);
xlabel('Day'); ylabel('Cycles/day');
title('Pump Cycles per Day'); grid on;

% (5) Raw LQR+I control action
figure(5);
plot(t_h, u_raw_hist, 'm','LineWidth',1.2);
xlabel('Time (h)'); ylabel('u_{raw} (duty)');
title('Raw LQR+I Control Signal (u_{raw})'); grid on;

% (6) Tracking error (sp - y)
figure(6);
plot(t_h, err, 'k','LineWidth',1.2);
xlabel('Time (h)'); ylabel('Error = sp - y');
title('Tracking Error vs. Time'); grid on;

% (7) True vs. Estimated State (first state variable)
figure(7);
plot(t_h, x_hist(1,:), 'b-', 'LineWidth', 1.2); hold on;
plot(t_h, xhat_hist(1,:), 'r--','LineWidth', 1.2);
xlabel('Time (h)'); ylabel('State #1');
legend('True x_1','Estimated \hat{x}_1','Location','best');
title('True vs. Estimated Soil‐Moisture State (State #1)'); grid on;
