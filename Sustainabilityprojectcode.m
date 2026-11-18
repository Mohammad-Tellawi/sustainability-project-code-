%% 1. Panel settings
plate.a = 0.15;       % Panel length (m)
plate.b = 0.13;       % Panel width (m)
plate.h = 0.002;      % Panel thickness (m)
plate.rho = 2500;     % Glass density (kg/m^3)
plate.f0 = 510;       % Resonance frequency (Hz)
plate.zeta = 0.02;    % Damping ratio

%% 2. Motor settings
motor.BL = 3;         % Motor force constant
motor.R = 4;          % Motor resistance (ohms)

%% 3. Frequency settings
sweep.fStart = 200;   % Starting frequency (Hz)
sweep.fEnd = 2000;    % Ending frequency (Hz)
sweep.T = 20;         % Time for one sweep (seconds)
sweep.count = 3;      % Number of sweeps
sweep.dt = 0.05;      % Time step (seconds)

%% 4. Dust settings
dirt.adhesion = 1e-3; % Dust sticking force
dirt.density = 2650;  % Dust density (kg/m^3)
dirt.median = 30e-6;  % Average dust size (m)
dirt.N = 1000;        % Number of dust particles
dirt.time = 0.1;     % Time needed to remove dust

%% 5. Solar panel settings
pv.power = 10;        % Clean panel power (W)
pv.loss = 0.25;       % Initial power loss

%% 6. Safety limits
% These values are assumptions and should be tested.

safe.maxFreq = 200;   % Selected frequency limit (Hz)
safe.maxG = 10;       % Selected vibration limit (g)

% Amplifier powers to compare
amplifierPowers = [3 1 10 25];

%% 7. Create dust particles
rng(1);

% Generate random dust particle sizes
dirt.d = dirt.median * exp(0.6 * randn(dirt.N,1));

% Calculate the acceleration needed to remove dust
dustMass = dirt.density * pi/6 * dirt.d.^3;
dustForce = dirt.adhesion * dirt.d;

dirt.needed = dustForce ./ dustMass;

%% 8. Run the cleaning simulation
% Run the simulation for each amplifier power

results = struct('t', {}, 'freq', {}, 'mass', {}, 'shaking', {}, 'areaRemoved', {}, 'power', {}, 'energy', {});

for k = 1:length(amplifierPowers)

    results(k) = cleaningRun(amplifierPowers(k), plate, motor, sweep, dirt, pv);

end

% Use the first amplifier power (3 W) as the main result
base = results(1);

%% 9. Display results
peakG = max(base.shaking) / 9.81;

fprintf('Panel mass        : %.2f kg\n', base.mass);

fprintf('Peak shaking      : %.0f m/s^2 (%.1f g)\n', max(base.shaking), peakG);

fprintf('Dust area removed : %.0f %%\n', 100 * base.areaRemoved(end));

fprintf('PV power          : %.2f W -> %.2f W\n\n', base.power(1), base.power(end));

fprintf('Amplifier   Dust removed   Power after   Energy used   Peak shaking\n');

for k = 1:length(results)

    fprintf('%6.0f W    %8.0f %%    %9.2f W    %8.3f Wh    %7.1f g\n', amplifierPowers(k), 100 * results(k).areaRemoved(end), results(k).power(end), results(k).energy, max(results(k).shaking) / 9.81);

end

%% 10. Safety check
fprintf('\nSafety check (limits are assumptions):\n');

% Check the frequency limit
if sweep.fEnd > safe.maxFreq

    fprintf('  WARNING: sweep reaches %d Hz, above the %d Hz selected limit.\n', sweep.fEnd, safe.maxFreq);

else

    fprintf('  OK: the sweep stays within %d Hz.\n', safe.maxFreq);

end

% Check the vibration limit
if peakG > safe.maxG

    fprintf('  WARNING: peak shaking %.1f g is above your limit of %.1f g.\n', peakG, safe.maxG);

else

    fprintf('  OK: peak shaking %.1f g is below your limit of %.1f g.\n', peakG, safe.maxG);

end

%% 11. Create the graphs
figure('Color','w');

% Graph 1: Frequency sweep
subplot(2,2,1);

plot(base.t, base.freq, 'LineWidth',1.5);
yline(safe.maxFreq,'r--','tested limit');

grid on;
xlabel('Time [s]');
ylabel('Frequency [Hz]');
title('Frequency sweep');

% Graph 2: Panel vibration
subplot(2,2,2);

plot(base.freq, base.shaking/9.81,'.');
yline(safe.maxG,'r--','safe limit');

grid on;
xlabel('Frequency [Hz]');
ylabel('Shaking [g]');
title('Panel shaking');

% Graph 3: Solar power
subplot(2,2,3);

plot(base.t, base.power,'LineWidth',1.5);
hold on;
yline(pv.power,'g--','clean panel');

grid on;
xlabel('Time [s]');
ylabel('PV power [W]');
title('Power rises as dust falls off');

% Graph 4: Amplifier power comparison
subplot(2,2,4);

dustRemoved = zeros(1,length(results));

for k = 1:length(results)

    dustRemoved(k) = 100 * results(k).areaRemoved(end);

end

bar(categorical(string(amplifierPowers) + " W"), dustRemoved);

grid on;
ylabel('Dust removed [%]');
title('Effect of amplifier power');


%% 12. Function for one cleaning run
function out = cleaningRun(P, plate, motor, sweep, dirt, pv)

    % Create time and frequency values
    t = 0:sweep.dt:sweep.T*sweep.count-sweep.dt;

    freq = sweep.fStart * (sweep.fEnd/sweep.fStart).^(mod(t,sweep.T)/sweep.T);

    % Calculate panel mass and motor force
    mass = plate.rho * plate.a * plate.b * plate.h;

    force = motor.BL * sqrt(2*P/motor.R);

    % Calculate how much the panel shakes
    r = freq / plate.f0;

    shaking = (force/mass) * r.^2 ./ sqrt((1-r.^2).^2 + (2*plate.zeta*r).^2);

    % Start with all dust particles still on the panel
    timeShaken = zeros(dirt.N,1);
    removed = false(dirt.N,1);

    areaRemoved = zeros(size(t));

    % Check the dust at every time step
    for i = 1:length(t)

        % Check if the vibration is strong enough
        timeShaken = timeShaken + sweep.dt * (shaking(i) >= dirt.needed);

        % Remove dust after enough shaking time
        removed = removed | (timeShaken >= dirt.time);

        % Calculate the percentage of dust area removed
        areaRemoved(i) = sum(dirt.d(removed).^2) / sum(dirt.d.^2);

    end

    % Calculate solar power after cleaning
    power = pv.power * (1-pv.loss*(1-areaRemoved));

    % Calculate amplifier energy usage
    energy = P * t(end) / 3600;

    % Save the results
    out.t = t;
    out.freq = freq;
    out.mass = mass;
    out.shaking = shaking;
    out.areaRemoved = areaRemoved;
    out.power = power;
    out.energy = energy;

end