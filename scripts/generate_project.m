function generate_project()
%GENERATE_PROJECT Create MATLAB Project and initial Simulink architecture.

rootDir = fileparts(fileparts(mfilename('fullpath')));
projectName = "DamagedAircraftOnlineIDDecision";

dirs = ["models", "scripts", "functions", "data", "results", "docs"];
for d = dirs
    if ~exist(fullfile(rootDir, d), 'dir')
        mkdir(fullfile(rootDir, d));
    end
end

projFile = dir(fullfile(rootDir, "*.prj"));
if isempty(projFile)
    proj = matlab.project.createProject('Folder', rootDir, 'Name', projectName);
else
    proj = openProject(rootDir);
end

proj.addFolderIncludingChildFiles(fullfile(rootDir, "models"));
proj.addFolderIncludingChildFiles(fullfile(rootDir, "scripts"));
proj.addFolderIncludingChildFiles(fullfile(rootDir, "functions"));
proj.addFolderIncludingChildFiles(fullfile(rootDir, "data"));
proj.addFolderIncludingChildFiles(fullfile(rootDir, "results"));
proj.addFolderIncludingChildFiles(fullfile(rootDir, "docs"));

proj.addPath(fullfile(rootDir, "scripts"));
proj.addPath(fullfile(rootDir, "functions"));
proj.addPath(fullfile(rootDir, "data"));
proj.addStartupFile(fullfile(rootDir, "scripts", "init_project.m"));

try
    proj.addShortcut(fullfile(rootDir, "models", "main_damaged_aircraft.slx"));
catch
end

init_project();
createMainModel(rootDir);
disp("Project generation complete.");
end

function createMainModel(rootDir)
modelName = "main_damaged_aircraft";
modelPath = fullfile(rootDir, "models", modelName + ".slx");

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

bdclose('all');

if isfile(modelPath)
    delete(modelPath);
end

load_system('simulink');
load_system('aerolib6dof');
load_system('aerolibatmos');
load_system('aerolibgravity');
load_system('aerolibwind');

new_system(modelName);
open_system(modelName);
set_param(modelName, ...
    'Solver', 'ode45', ...
    'StopTime', '10', ...
    'SaveFormat', 'StructureWithTime', ...
    'SignalLogging', 'on', ...
    'SignalLoggingName', 'logsout', ...
    'InitFcn', 'init_project;');

add_block('simulink/Sources/Constant', modelName + "/theta_d", ...
    'Value', 'theta_d', ...
    'Position', [40 360 110 390]);

add_block('simulink/Ports & Subsystems/Subsystem', modelName + "/Environment", ...
    'Position', [180 40 420 230]);
add_block('simulink/Ports & Subsystems/Subsystem', modelName + "/Actuator_Propulsion", ...
    'Position', [210 250 470 430]);
add_block('simulink/Ports & Subsystems/Subsystem', modelName + "/Damage_Injection", ...
    'Position', [520 250 820 430]);
add_block('simulink/Ports & Subsystems/Subsystem', modelName + "/Decision_Logic", ...
    'Position', [180 440 420 560]);
add_block('simulink/Ports & Subsystems/Subsystem', modelName + "/Sensor_Output_Bus", ...
    'Position', [980 190 1220 370]);
add_block('simulink/Ports & Subsystems/Subsystem', modelName + "/Online Damage Identifier", ...
    'Position', [980 420 1220 560]);
add_block('simulink/Signal Routing/Mux', modelName + "/State_Vector_Mux", ...
    'Inputs', '4', ...
    'Position', [500 70 505 210]);

add_block('aerolib6dof/6DoF (Euler Angles)', modelName + "/6DOF_FixedWing", ...
    'Position', [790 60 930 180]);

configure6DoF(modelName + "/6DOF_FixedWing");
configureEnvironment(modelName + "/Environment");
configureActuatorPropulsion(modelName + "/Actuator_Propulsion");
configureDamageInjection(modelName + "/Damage_Injection");
configureSensorBus(modelName + "/Sensor_Output_Bus");
configureDecisionLogic(modelName + "/Decision_Logic");
configureOnlineIdentifier(modelName + "/Online Damage Identifier");

add_block('simulink/Math Operations/Sum', modelName + "/Sum_Forces", ...
    'Inputs', '++', ...
    'Position', [640 95 660 125]);
add_block('simulink/Math Operations/Sum', modelName + "/Sum_Moments", ...
    'Inputs', '++', ...
    'Position', [640 145 660 175]);
add_block('simulink/Sinks/Terminator', modelName + "/eta_hat_sink", ...
    'Position', [1260 490 1280 510]);
add_block('simulink/Sinks/Terminator', modelName + "/identifier_confidence_sink", ...
    'Position', [1260 530 1280 550]);
add_block('simulink/Sinks/To Workspace', modelName + "/state_log", ...
    'VariableName', 'state_log', ...
    'SaveFormat', 'StructureWithTime', ...
    'Position', [640 25 720 45]);
add_block('simulink/Sinks/To Workspace', modelName + "/cmd_log", ...
    'VariableName', 'cmd_log', ...
    'SaveFormat', 'StructureWithTime', ...
    'Position', [520 470 600 490]);
add_block('simulink/Sinks/To Workspace', modelName + "/eta_log", ...
    'VariableName', 'eta_log', ...
    'SaveFormat', 'StructureWithTime', ...
    'Position', [840 350 920 370]);
add_block('simulink/Sinks/To Workspace', modelName + "/identifier_log", ...
    'VariableName', 'identifier_log', ...
    'SaveFormat', 'StructureWithTime', ...
    'Position', [1260 450 1340 470]);

add_line(modelName, '6DOF_FixedWing/1', 'State_Vector_Mux/1', 'autorouting', 'on');
add_line(modelName, '6DOF_FixedWing/2', 'State_Vector_Mux/2', 'autorouting', 'on');
add_line(modelName, '6DOF_FixedWing/3', 'State_Vector_Mux/3', 'autorouting', 'on');
add_line(modelName, '6DOF_FixedWing/5', 'State_Vector_Mux/4', 'autorouting', 'on');

add_line(modelName, 'State_Vector_Mux/1', 'Damage_Injection/1', 'autorouting', 'on');
add_line(modelName, 'theta_d/1', 'Damage_Injection/3', 'autorouting', 'on');
add_line(modelName, 'State_Vector_Mux/1', 'Actuator_Propulsion/1', 'autorouting', 'on');
add_line(modelName, 'theta_d/1', 'Actuator_Propulsion/3', 'autorouting', 'on');

add_line(modelName, 'Decision_Logic/1', 'Actuator_Propulsion/2', 'autorouting', 'on');
add_line(modelName, 'Decision_Logic/1', 'Damage_Injection/2', 'autorouting', 'on');

add_line(modelName, 'Actuator_Propulsion/1', 'Sum_Forces/1', 'autorouting', 'on');
add_line(modelName, 'Damage_Injection/1', 'Sum_Forces/2', 'autorouting', 'on');
add_line(modelName, 'Actuator_Propulsion/2', 'Sum_Moments/1', 'autorouting', 'on');
add_line(modelName, 'Damage_Injection/2', 'Sum_Moments/2', 'autorouting', 'on');

add_line(modelName, 'Sum_Forces/1', '6DOF_FixedWing/1', 'autorouting', 'on');
add_line(modelName, 'Sum_Moments/1', '6DOF_FixedWing/2', 'autorouting', 'on');

add_line(modelName, 'State_Vector_Mux/1', 'Sensor_Output_Bus/1', 'autorouting', 'on');
add_line(modelName, 'Environment/1', 'Sensor_Output_Bus/2', 'autorouting', 'on');
add_line(modelName, 'Damage_Injection/3', 'Sensor_Output_Bus/3', 'autorouting', 'on');
add_line(modelName, 'Sensor_Output_Bus/1', 'Decision_Logic/1', 'autorouting', 'on');
add_line(modelName, 'theta_d/1', 'Decision_Logic/2', 'autorouting', 'on');
add_line(modelName, 'State_Vector_Mux/1', 'Online Damage Identifier/1', 'autorouting', 'on');
add_line(modelName, 'Decision_Logic/1', 'Online Damage Identifier/2', 'autorouting', 'on');
add_line(modelName, 'Damage_Injection/3', 'Online Damage Identifier/3', 'autorouting', 'on');
add_line(modelName, 'theta_d/1', 'Online Damage Identifier/4', 'autorouting', 'on');
add_line(modelName, 'Online Damage Identifier/1', 'eta_hat_sink/1', 'autorouting', 'on');
add_line(modelName, 'Online Damage Identifier/2', 'identifier_confidence_sink/1', 'autorouting', 'on');
add_line(modelName, 'State_Vector_Mux/1', 'state_log/1', 'autorouting', 'on');
add_line(modelName, 'Decision_Logic/1', 'cmd_log/1', 'autorouting', 'on');
add_line(modelName, 'Damage_Injection/3', 'eta_log/1', 'autorouting', 'on');
add_line(modelName, 'Online Damage Identifier/1', 'identifier_log/1', 'autorouting', 'on');

Simulink.BlockDiagram.arrangeSystem(modelName);
save_system(modelName, modelPath);
close_system(modelName);
end

function configure6DoF(blockPath)
set_param(blockPath, ...
    'Mass', 'P.aircraft.mass', ...
    'Inertia', 'P.aircraft.inertia', ...
    'xme_0', 'P.initial.pned_m''', ...
    'Vm_0', 'P.initial.uvw_mps''', ...
    'eul_0', 'P.initial.euler_rad''', ...
    'pm_0', 'P.initial.pqr_rps''');
end

function configureEnvironment(blockPath)
open_system(blockPath);
Simulink.SubSystem.deleteContents(blockPath);

add_block('simulink/Ports & Subsystems/Out1', blockPath + "/env_bus", ...
    'Position', [480 120 510 140]);

add_block('simulink/Sources/Constant', blockPath + "/altitude_m", ...
    'Value', '-P.initial.pned_m(3)', ...
    'Position', [30 20 95 50]);
add_block('simulink/Sources/Constant', blockPath + "/latitude_rad", ...
    'Value', '0', ...
    'Position', [30 85 95 115]);
add_block('simulink/Sources/Constant', blockPath + "/gust_seed", ...
    'Value', '0', ...
    'Position', [30 165 95 195]);
add_block('simulink/Signal Attributes/Signal Specification', blockPath + "/altitude_unit", ...
    'Unit', 'm', ...
    'Dimensions', '1', ...
    'Position', [105 20 140 50]);
add_block('simulink/Signal Attributes/Signal Specification', blockPath + "/latitude_unit", ...
    'Unit', 'deg', ...
    'Dimensions', '1', ...
    'Position', [105 85 140 115]);

add_block('aerolibatmos/ISA Atmosphere Model', blockPath + "/Atmosphere", ...
    'Position', [165 20 305 80]);
add_block('aerolibgravity/WGS84 Gravity Model', blockPath + "/Gravity", ...
    'Position', [165 90 305 150]);
add_block('aerolibwind/Discrete Wind Gust Model', blockPath + "/Wind", ...
    'Position', [165 165 305 225]);
add_block('simulink/Signal Routing/Bus Creator', blockPath + "/BusCreator", ...
    'Inputs', '3', ...
    'Position', [390 108 410 172]);

add_line(blockPath, 'altitude_m/1', 'altitude_unit/1', 'autorouting', 'on');
add_line(blockPath, 'latitude_rad/1', 'latitude_unit/1', 'autorouting', 'on');
add_line(blockPath, 'altitude_unit/1', 'Atmosphere/1', 'autorouting', 'on');
add_line(blockPath, 'altitude_unit/1', 'Gravity/1', 'autorouting', 'on');
add_line(blockPath, 'latitude_unit/1', 'Gravity/2', 'autorouting', 'on');
add_line(blockPath, 'gust_seed/1', 'Wind/1', 'autorouting', 'on');
add_line(blockPath, 'Atmosphere/1', 'BusCreator/1', 'autorouting', 'on');
add_line(blockPath, 'Gravity/1', 'BusCreator/2', 'autorouting', 'on');
add_line(blockPath, 'Wind/1', 'BusCreator/3', 'autorouting', 'on');
add_line(blockPath, 'BusCreator/1', 'env_bus/1', 'autorouting', 'on');
end

function configureActuatorPropulsion(blockPath)
open_system(blockPath);
Simulink.SubSystem.deleteContents(blockPath);

add_block('simulink/Ports & Subsystems/In1', blockPath + "/x", ...
    'Position', [25 40 55 60]);
add_block('simulink/Ports & Subsystems/In1', blockPath + "/u_cmd", ...
    'Position', [25 90 55 110]);
add_block('simulink/Ports & Subsystems/In1', blockPath + "/theta_d", ...
    'Position', [25 140 55 160]);
add_block('simulink/Ports & Subsystems/Out1', blockPath + "/F_cmd_b_N", ...
    'Position', [460 60 490 80]);
add_block('simulink/Ports & Subsystems/Out1', blockPath + "/M_cmd_b_Nm", ...
    'Position', [460 125 490 145]);

add_block('simulink/Signal Routing/Mux', blockPath + "/InputMux", ...
    'Inputs', '3', ...
    'Position', [105 72 110 138]);
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', blockPath + "/AirframeForceMoment", ...
    'MATLABFcn', 'simple_aircraft_force_moment_model', ...
    'OutputDimensions', '6', ...
    'Position', [170 78 310 132]);
add_block('simulink/Signal Routing/Demux', blockPath + "/ForceMomentDemux", ...
    'Outputs', '[3 3]', ...
    'Position', [370 78 375 142]);

add_line(blockPath, 'x/1', 'InputMux/1', 'autorouting', 'on');
add_line(blockPath, 'u_cmd/1', 'InputMux/2', 'autorouting', 'on');
add_line(blockPath, 'theta_d/1', 'InputMux/3', 'autorouting', 'on');
add_line(blockPath, 'InputMux/1', 'AirframeForceMoment/1', 'autorouting', 'on');
add_line(blockPath, 'AirframeForceMoment/1', 'ForceMomentDemux/1', 'autorouting', 'on');
add_line(blockPath, 'ForceMomentDemux/1', 'F_cmd_b_N/1', 'autorouting', 'on');
add_line(blockPath, 'ForceMomentDemux/2', 'M_cmd_b_Nm/1', 'autorouting', 'on');
end

function configureDamageInjection(blockPath)
open_system(blockPath);
Simulink.SubSystem.deleteContents(blockPath);

add_block('simulink/Ports & Subsystems/In1', blockPath + "/x", ...
    'Position', [20 48 50 62]);
add_block('simulink/Ports & Subsystems/In1', blockPath + "/u", ...
    'Position', [20 98 50 112]);
add_block('simulink/Ports & Subsystems/In1', blockPath + "/theta_d", ...
    'Position', [20 148 50 162]);
add_block('simulink/Signal Routing/Mux', blockPath + "/InputMux", ...
    'Inputs', '3', ...
    'Position', [95 72 100 138]);
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', blockPath + "/DamageMap", ...
    'MATLABFcn', 'damage_output_vector', ...
    'OutputDimensions', '10', ...
    'Position', [145 78 265 132]);
add_block('simulink/Signal Routing/Demux', blockPath + "/DamageDemux", ...
    'Outputs', '[3 3 4]', ...
    'Position', [295 78 300 162]);
add_block('simulink/Ports & Subsystems/Out1', blockPath + "/deltaF_b_N", ...
    'Position', [335 55 365 69]);
add_block('simulink/Ports & Subsystems/Out1', blockPath + "/deltaM_b_Nm", ...
    'Position', [335 105 365 119]);
add_block('simulink/Ports & Subsystems/Out1', blockPath + "/eta_ctrl", ...
    'Position', [335 155 365 169]);

add_line(blockPath, 'x/1', 'InputMux/1', 'autorouting', 'on');
add_line(blockPath, 'u/1', 'InputMux/2', 'autorouting', 'on');
add_line(blockPath, 'theta_d/1', 'InputMux/3', 'autorouting', 'on');
add_line(blockPath, 'InputMux/1', 'DamageMap/1', 'autorouting', 'on');
add_line(blockPath, 'DamageMap/1', 'DamageDemux/1', 'autorouting', 'on');
add_line(blockPath, 'DamageDemux/1', 'deltaF_b_N/1', 'autorouting', 'on');
add_line(blockPath, 'DamageDemux/2', 'deltaM_b_Nm/1', 'autorouting', 'on');
add_line(blockPath, 'DamageDemux/3', 'eta_ctrl/1', 'autorouting', 'on');
end

function configureSensorBus(blockPath)
open_system(blockPath);
Simulink.SubSystem.deleteContents(blockPath);

add_block('simulink/Ports & Subsystems/In1', blockPath + "/state_meas", ...
    'Position', [20 48 50 62]);
add_block('simulink/Ports & Subsystems/In1', blockPath + "/env_bus", ...
    'Position', [20 98 50 112]);
add_block('simulink/Ports & Subsystems/In1', blockPath + "/eta_ctrl", ...
    'Position', [20 148 50 162]);
add_block('simulink/Signal Routing/Bus Creator', blockPath + "/BusCreator", ...
    'Inputs', '3', ...
    'Position', [175 77 195 143]);
add_block('simulink/Ports & Subsystems/Out1', blockPath + "/sensor_bus", ...
    'Position', [285 105 315 119]);

add_line(blockPath, 'state_meas/1', 'BusCreator/1', 'autorouting', 'on');
add_line(blockPath, 'env_bus/1', 'BusCreator/2', 'autorouting', 'on');
add_line(blockPath, 'eta_ctrl/1', 'BusCreator/3', 'autorouting', 'on');
add_line(blockPath, 'BusCreator/1', 'sensor_bus/1', 'autorouting', 'on');
end

function configureDecisionLogic(blockPath)
open_system(blockPath);
Simulink.SubSystem.deleteContents(blockPath);

add_block('simulink/Ports & Subsystems/In1', blockPath + "/sensor_bus", ...
    'Position', [30 58 60 72]);
add_block('simulink/Ports & Subsystems/In1', blockPath + "/theta_d", ...
    'Position', [30 118 60 132]);
add_block('simulink/Sinks/Terminator', blockPath + "/sensor_bus_sink", ...
    'Position', [105 55 125 75]);
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', blockPath + "/DecisionBridge", ...
    'MATLABFcn', 'decision_command_vector', ...
    'OutputDimensions', '4', ...
    'Position', [170 90 300 140]);
add_block('simulink/Ports & Subsystems/Out1', blockPath + "/u_cmd_out", ...
    'Position', [360 108 390 122]);

add_line(blockPath, 'sensor_bus/1', 'sensor_bus_sink/1', 'autorouting', 'on');
add_line(blockPath, 'theta_d/1', 'DecisionBridge/1', 'autorouting', 'on');
add_line(blockPath, 'DecisionBridge/1', 'u_cmd_out/1', 'autorouting', 'on');
end

function configureOnlineIdentifier(blockPath)
open_system(blockPath);
Simulink.SubSystem.deleteContents(blockPath);

add_block('simulink/Ports & Subsystems/In1', blockPath + "/state_summary", ...
    'Position', [30 58 60 72]);
add_block('simulink/Ports & Subsystems/In1', blockPath + "/control_input", ...
    'Position', [30 98 60 112]);
add_block('simulink/Ports & Subsystems/In1', blockPath + "/feature_summary", ...
    'Position', [30 138 60 152]);
add_block('simulink/Ports & Subsystems/In1', blockPath + "/theta_d", ...
    'Position', [30 178 60 192]);
add_block('simulink/Sinks/Terminator', blockPath + "/state_sink", ...
    'Position', [95 55 115 75]);
add_block('simulink/Sinks/Terminator', blockPath + "/control_sink", ...
    'Position', [95 95 115 115]);
add_block('simulink/Sinks/Terminator', blockPath + "/feature_sink", ...
    'Position', [95 135 115 155]);
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', blockPath + "/IdentifierBridge", ...
    'MATLABFcn', 'online_identifier_placeholder_vector', ...
    'OutputDimensions', '5', ...
    'Position', [150 155 280 199]);
add_block('simulink/Signal Routing/Demux', blockPath + "/IdentifierDemux", ...
    'Outputs', '[4 1]', ...
    'Position', [305 153 310 201]);
add_block('simulink/Ports & Subsystems/Out1', blockPath + "/eta_hat", ...
    'Position', [350 155 380 169]);
add_block('simulink/Ports & Subsystems/Out1', blockPath + "/confidence", ...
    'Position', [350 195 380 209]);

add_line(blockPath, 'state_summary/1', 'state_sink/1', 'autorouting', 'on');
add_line(blockPath, 'control_input/1', 'control_sink/1', 'autorouting', 'on');
add_line(blockPath, 'feature_summary/1', 'feature_sink/1', 'autorouting', 'on');
add_line(blockPath, 'theta_d/1', 'IdentifierBridge/1', 'autorouting', 'on');
add_line(blockPath, 'IdentifierBridge/1', 'IdentifierDemux/1', 'autorouting', 'on');
add_line(blockPath, 'IdentifierDemux/1', 'eta_hat/1', 'autorouting', 'on');
add_line(blockPath, 'IdentifierDemux/2', 'confidence/1', 'autorouting', 'on');
end
