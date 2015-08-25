/*
This runs on the server machine after objects have initialised in the map. Anything the server needs to set up before the mission is started is set up here.
*/

//TFAR parameters you might want to change. The names should be self-explanatory.
#include "\task_force_radio\functions\common.sqf";

tf_no_auto_long_range_radio = true;
tf_give_personal_radio_to_regular_soldier = false;
tf_same_sw_frequencies_for_side = true;
tf_same_lr_frequencies_for_side = true;

tf_west_radio_code = "_bluefor"; //every side with the same radio code can talk to each other on radio, if on the same channel
tf_defaultWestBackpack = "tf_rt1523g"; //backpack radio
tf_defaultWestPersonalRadio = "tf_anprc152"; //fancy short range radio
tf_defaultWestRiflemanRadio = "tf_rf_7800str"; //shit short range radio
tf_defaultWestAirborneRadio = "tf_anarc210"; //never used this one idk

_settingsSwWest = false call TFAR_fnc_generateSwSettings;
_settingsSwWest set [2, ["31.10","31.15","31.20","31.25","31.90"]];
tf_freq_west = _settingsSwWest;

_settingsLrWest = false call TFAR_fnc_generateLrSettings;
_settingsLrWest set [2, ["31","32","33","40","50","51"]];
tf_freq_west_lr = _settingsLrWest;

//set respawn tickets to 0
[missionNamespace, 1] call BIS_fnc_respawnTickets;
[missionNamespace, -1] call BIS_fnc_respawnTickets;

{
	if (typeOf _x == "O_OFFICER_F") then {
		tango = _x;
	};
} forEach allUnits;

_veh = targetCarOne;
[
	_veh,
	["red",1],
		"HideGlass2", 1,
	[
		"HideBackpacks", 0,
		"HideBumper1", 0,
		"HideConstruction", 0,
		"Proxy", 0,
		"Destruct", 0
	]
] call BIS_fnc_initVehicle,

_veh = targetCarTwo;
[
	_veh,
	["guerilla_01",1],
	[
		"HideBackpacks", 0,
		"HideBumper1", 0,
		"HideConstruction", 0,
		"Proxy", 0,
		"Destruct", 0
	]
] call BIS_fnc_initVehicle;

_veh = playerCarOne;
[
	_veh,
	["blue",1],
	[
		"HideGlass2", 1,
		"HideBumper2", 0,
		"HideConstruction", 0,
		"Proxy", 0,
		"Destruct", 0
	]
] call BIS_fnc_initVehicle;

_veh = playerCarTwo;
[
	_veh,
	["blue",1],
	[
		"HideGlass2", 1,
		"HideBumper2", 0,
		"HideConstruction", 0,
		"Proxy", 0,
		"Destruct", 0
	]
] call BIS_fnc_initVehicle;


//Task setting: ["TaskName", locality, ["Description", "Title", "Marker"], target, "STATE", priority, showNotification, true] call BIS_fnc_setTask;
["tango", true, ["Capture or kill the militia leader.", "Neutralise leader", "marker_ao"], nil, "ASSIGNED", 3, false, true] call BIS_fnc_setTask;
_cacheTaskAssigned = false;
if (playersNumber west > 9) then {
	["caches", true, ["Destroy the militia ammo caches from both towns", "Destroy Caches", "marker_ao"], nil, "ASSIGNED", 2, false, true] call BIS_fnc_setTask;
	_cacheTaskAssigned = true;
};
["return", true, ["Return to base after the mission is complete", "Extract", "respawn_west"], nil, "ASSIGNED", 1, false, true] call BIS_fnc_setTask;

//Spawns a thread that will run a loop to keep an eye on mission progress and to end it when appropriate, checking which ending should be displayed.
_progress = [_cacheTaskAssigned] spawn {
	
	//Init all variables you need in this loop
	_ending = false;
	_playersDead = false;
	
	_killTaskUpdated = false;
	_cacheTaskAssigned = _this select 0;
	_destroyTaskUpdated = false;
	
	_thingDone = false;
	_playersInBase = false;
	_playersEscaped = false;

	//Starts a loop to check mission status every second, update tasks, and end mission when appropriate
	while {!_ending} do {
		
		sleep 1;
		
		//Mission ending condition check
		if ( forceEnding || _playersDead || (_thingDone && ( _playersInBase || _playersEscaped )) ) then {
			_ending = true;
			
			_tangoControlled = false;
			
			if (tango in trigger_base) then {
				_tangoControlled = true;
			} else {
				{
					_dist = _x distance tango;
					if (alive _x && _dist < 20) then {
						_tangoControlled = true;
					};
				} forEach playableUnits;
			};
			
			//_tangoCaptured = if (tango getVariable [QGVAR(isHandcuffed), false] && _tangoControlled) then { true; } else { false; };
			_tangoCaptured = false;
			if (!killConfirmed) then {
				if (!alive tango || _tangoCaptured) then {
					["tango", "SUCCEEDED", false] call BIS_fnc_taskSetState;
				} else {
					["tango", "FAILED", false] call BIS_fnc_taskSetState;
				};
			};
			
			if (_cacheTaskAssigned) then {
				if (!alive stashA && !alive stashB) then {
					["caches", "SUCCEEDED", false] call BIS_fnc_taskSetState;
				} else {
					["caches", "FAILED", false] call BIS_fnc_taskSetState;
				};
			};
			
			if (_playersInBase || _playersEscaped) then {
				if (_playersInBase) then {
					["tango", "SUCCEEDED", false] call BIS_fnc_taskSetState;
				} else {
					["tango", "CANCELED", false] call BIS_fnc_taskSetState;
				};
			} else {
				["return", "FAILED", false] call BIS_fnc_taskSetState;
			};
			
			_targetTown = if (targetLocation == 0) then { "A"; } else { "B"; };
			_recognitionState = if (!alive tango && !killConfirmed && (ambushTown == _targetTown && count assault != 0)) then { "initially"; } else { "officially"; };
			_successState = if (killConfirmed || _tangoCaptured) then { "success"; } else { "failure"; };
			if (_cacheTaskAssigned) then {
				if (killConfirmed || _tangoCaptured) then {
					if (!alive stashA && !alive stashB) then {
						_successState = format ["complete %1", _successState];
					} else {
						_successState = format ["partial %1", _successState];
					};
				} else {
					if (alive stashA && alive stashB) then {
						_successState = format ["complete %1", _successState];
					} else {
						_successState = format ["partial %1", _successState];
					};
				};
			};
			_successState = format ["a %1", _successState];
			_endTextStatus = format ["Operation HIFK was %1 considered %2", _recognitionState, _successState];
			
			_tasksTotal = "";
			if (_cacheTaskAssigned) then {
				if ( (killConfirmed || _tangoCaptured) && !alive stashA && !alive stashB ) then {
					_tasksTotal = "All tasks were completed successfully:";
				} else {
					
					if ( (killConfirmed || _tangoCaptured) || !alive stashA || !alive stashB ) then {
						_tasksTotal = "Some tasks were completed successfully:";
					} else {
						_tasksTotal = "No tasks were completed successfully:";
					};
				};
			};
			
			_targetStatus = "managed to escape";
			if (killConfirmed) then {
				_targetStatus = "was confirmed dead during the raid";
			} else {
				if (!alive tango) then {
					_targetStatus = ", however, was later confirmed dead";
				} else {
					if (_tangoCaptured) then {
						_targetStatus = "was successfully apprehended";
					};
				};
			};
			
			_cachesQualifier = "";
			_cachesStatus = "";
			if (_cacheTaskAssigned || (!alive stashA && !alive stashB)) then {
				if (!alive stashA && !alive stashB) then {
					_cachesStatus = "both weapons caches were destroyed";
					
					if (!alive tango || _tangoCaptured) then {
						_cachesQualifier = ", and ";
					} else {
						_cachesQualifier = ", but ";
					};
				} else {
					if (!alive stashA || !alive stashB) then {
						_cacheStatus = "one of the weapons caches was destroyed";
						
						if (!alive tango || _tangoCaptured) then {
						_cachesQualifier = ", and ";
						} else {
							_cachesQualifier = ", but ";
						};
					} else {
						_cacheStatus = "none of the weapons caches were destroyed";
						
						if (alive tango) then {
							_cachesQualifier = ", and ";
						} else {
							_cachesQualifier = ", but ";
						};
					};
				};
			};
			_endTextTasksOne = format ["%1", _tasksTotal]; 
			_endTextTasksTwo = format ["The target %1", _targetStatus];
			_endTextTasksThree = format ["%1%2", _cachesQualifier, _cachesStatus];
			_endTextTasks = format ["%1%2%3", _endTextTasksOne, _endTextTasksTwo, _endTextTasksThree];
			
			_casualtiesPlayers = "";
			_totalPlayers = count allPlayers;
			_deadPlayers = 0;
			{
				if (!alive _x) then {
					_deadPlayers = _deadPlayers + 1;
				};
			} forEach allPlayers;
			_percentDead = _deadPlayers/(count allPlayers);

			if (_deadPlayers == 0) then {
				_casualtiesPlayers = "no";
			} else {
				if (_percentDead < 0.3) then {
					_casualtiesPlayers = "significant";
				} else {
					if (_percentDead < 0.6) then {
						_casualtiesPlayers = "heavy";
					} else {
						_casualtiesPlayers = "catastrophic";
					};
				};
			};

			_casualtiesEnemy = 0;
			_casualtiesCivilian = 0;
			{
				if (side _x == east || side _x == resistance) then {
					if (!alive _x) then {
						_casualtiesEnemy = _casualtiesEnemy + 1;
					};
				} else {
					if (side _x == civilian) then {
						if (!alive _x) then {
							_casualtiesCivilian = _casualtiesCivilian + 1;
						};
					};
				};
			} forEach allUnits;

			_assaultText = "";
			if (count assault > 0 || ambushActivated) then {
				_assaultText = "However, other combat activity during the morning of the operation has made it impossible to estimate how many of these were a direct result of the raid.";
			};
			
			_endTextCasualtiesOne = format ["The special jaeger team suffered %1 casualties", _casualtiesPlayers];
			_endTextCasualtiesTwo =	format ["with %1 enemy combatants and %2 civilians killed", _casualtiesEnemy, _casualtiesCivilian];
			_endTextCasualtiesThree = format ["%1", _assaultText];
			_endTextCasualties = format ["%1, %2. %3", _endTextCasualtiesOne, _endTextCasualtiesTwo, _endTextCasualtiesThree];
			
			_endState = "";
			if (alive tango) then {
				_endState = "loss";
			} else {
				_endState = "win";
			};
			
			if (_cacheTaskAssigned || (!alive stashA && !alive stashB)) then {
				if (_endState == "win") then {
					if (!alive stashA && !alive stashB) then {
						_endState = format ["total%1", _endState];
					} else {
						_endState = format ["partial%1", _endState];
					};
				} else {
					if (!alive stashA && !alive stashB) then {
						_endState = format ["partial%1", _endState];
					} else {
						_endState = format ["total%1", _endState];
					};
				};
			} else {
				_endState = format ["total%1", _endState];
			};
			
			_commendationText = "";
			if (_casualtiesCivilian == 0 && _endState == "totalwin") then {
				_commendationText = "The finnish special jaegers have earned international praise for their efficiency and professionalism during this important operation.";
			} else {
				if ( (_casualtiesCivilian > 0 && (count assault == 0)) || _endState == "totalloss" || (_endState == "partialloss" && _casualtiesPlayers != "no")) then {
					_commendationText = "The decision to send such an inexperienced unit on an important mission, in an apparent attempt to get them important combat experience at the cost of the mission's success, has been heavily criticized.";
				};
			};
			_endTextPS = format ["%1", _commendationText];
			
			//Runs end.sqf on everyone. For varying mission end states, calculate the correct one here and send it as an argument for end.sqf
			[[[_endState, _endTextStatus, _endTextTasks, _endTextCasualties, _endTextPS],"end.sqf"], "BIS_fnc_execVM", true, false] spawn BIS_fnc_MP;
		};
		
		//Sets _playersDead as true if nobody is still alive
		_playersDead = true;
		{
			if (alive _x) then {
				_playersDead = false;
			};
		} forEach playableUnits;
		
		_thingDone = if (!alive tango || !alive stashA || !alive stashB || !canMove heko) then { true; } else { false; };
		
		_playersInBase = true;
		{
			if ((alive _x) && (!(_x in trigger_base) || ( vehicle _x != _x) )) then {
				_playersInBase = false;
			};
		} forEach playableUnits;
		
		_playersEscaped = true;
		if (!canMove heko) then {
			{
				if (alive _x && _x in trigger_escapeArea) then {
					_playersEscaped = false;
				};
			} forEach playableUnits;
		} else {
			_playersEscaped = false;
		};
		
		if (killConfirmed && !_killTaskUpdated) then {
			["tango", "SUCCEEDED", false] call BIS_fnc_taskSetState;
			[ ["TaskSucceeded", ["Kill Confirmed"]], "BIS_fnc_showNotification"] call BIS_fnc_MP;
			_killTaskUpdated = true;
		};
		
		if (!alive stashA && !alive stashB && !_destroyTaskUpdated) then {
			["caches", "SUCCEEDED", false] call BIS_fnc_taskSetState;
			[ ["TaskSucceeded", ["Caches Destroyed"]], "BIS_fnc_showNotification"] call BIS_fnc_MP;
			_destroyTaskUpdated = true;
		};
	};
};

//client inits wait for serverInit to be true before starting, to make sure all variables the server sets up are set up before clients try to refer to them (which would cause errors)
serverInit = true;
publicVariable "serverInit";