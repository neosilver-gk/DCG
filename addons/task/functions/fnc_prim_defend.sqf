/*
Author:
Nicholas Clark (SENSEI)

Description:
primary task - defend supplies

Arguments:
0: forced task position <ARRAY>

Return:
none
__________________________________________________________________*/
#define TASK_PRIMARY
#define TASK_NAME 'Defend Supplies'
#define COUNTDOWN 450
#define FRIENDLY_COUNT 12
#define FOB_COND !isNull EGVAR(fob,location) && {!(CHECK_DIST2D(locationPosition EGVAR(fob,location),locationPosition EGVAR(main,baseLocation),EGVAR(main,baseRadius)))} && {random 1 < 0.5}
#include "script_component.hpp"

params [["_position",[]]];

// CREATE TASK
_taskID = str diag_tickTime;
_type = "";
GVAR(defend_enemies) = [];
_vehPos = [];

if (_position isEqualTo []) then {
	if (FOB_COND) then {
		_position = locationPosition EGVAR(fob,location);
	} else {
		_position = [EGVAR(main,center),EGVAR(main,range),"house"] call EFUNC(main,findRuralPos);
		if !(_position isEqualTo []) then {
			_position = _position select 1;
		};
	};
};

if (_position isEqualTo []) exitWith {
	[TASK_TYPE,0] call FUNC(select);
};

for "_i" from 1 to 100 do {
	_vehPos = [_position,0,50,16,0,.35] call EFUNC(main,findPosSafe);

	if !(_vehPos isEqualTo _position) exitWith {};

	_vehPos = [];
};

if (_vehPos isEqualTo []) exitWith {
	[TASK_TYPE,0] call FUNC(select);
};

call {
	if (EGVAR(main,playerSide) isEqualTo EAST) then {
		_type = "O_Truck_03_ammo_F";
	};
	if (EGVAR(main,playerSide) isEqualTo RESISTANCE) then {
		_type = "I_Truck_02_ammo_F";
	};
	_type = "B_Truck_01_ammo_F";
};

_truck = _type createVehicle _vehPos;
_truck lock 3;
_truck setDir random 360;
[_truck] call EFUNC(main,setVehDamaged);
_truck allowDamage false;
_driver = (createGroup CIVILIAN) createUnit ["C_man_w_worker_F", [0,0,0], [], 0, "NONE"];
_driver moveInDriver _truck;
_driver allowFleeing 0;
_driver setBehaviour "CARELESS";
_driver setCombatMode "BLUE";
_driver disableAI "TARGET";
_driver disableAI "AUTOTARGET";
_truck allowCrewInImmobile true;

_grp = [_position,0,FRIENDLY_COUNT,EGVAR(main,playerSide)] call EFUNC(main,spawnGroup);

[
	{count units (_this select 0) >= FRIENDLY_COUNT},
	{
		[units (_this select 0)] call EFUNC(main,setPatrol);
	},
	[_grp]
] call CBA_fnc_waitUntilAndExecute;

// SET TASK
_taskDescription = format ["A friendly unit is resupplying at %1. Move to the area and provide security while the transport is idle.", mapGridPosition _position];

[true,_taskID,[_taskDescription,TASK_TITLE,""],_position,false,true,"defend"] call EFUNC(main,setTask);

// PUBLISH TASK
TASK_PUBLISH(_position);

// TASK HANDLER
[{
	params ["_args","_idPFH"];
	_args params ["_taskID","_truck","_grp"];

	if (TASK_GVAR isEqualTo []) exitWith {
		[_idPFH] call CBA_fnc_removePerFrameHandler;
		[_taskID, "CANCELED"] call EFUNC(main,setTaskState);
		((units _grp) + [_truck]) call EFUNC(main,cleanup);
		[TASK_TYPE] call FUNC(select);
	};

	if ({CHECK_VECTORDIST(getPosASL _x,getPosASL _truck,TASK_DIST_START)} count allPlayers > 0) exitWith {
		[_idPFH] call CBA_fnc_removePerFrameHandler;
		[COUNTDOWN,60,TASK_NAME,"",call CBA_fnc_players] call EFUNC(main,setTimer);
		_enemyCount = [TASK_UNIT_MIN,TASK_UNIT_MAX] call EFUNC(main,setStrength);

		[{
			params ["_args","_idPFH"];
			_args params ["_taskID","_truck","_grp","_enemyCount","_time"];

			if (TASK_GVAR isEqualTo []) exitWith {
				[_idPFH] call CBA_fnc_removePerFrameHandler;
				[_taskID, "CANCELED"] call EFUNC(main,setTaskState);
				EGVAR(main,exitTimer) = true;
				((units _grp) + GVAR(defend_enemies) + [_truck]) call EFUNC(main,cleanup);
				[TASK_TYPE] call FUNC(select);
			};

			if ({CHECK_VECTORDIST(getPosASL _x,getPosASL _truck,TASK_DIST_FAIL)} count allPlayers isEqualTo 0) exitWith {
				[_idPFH] call CBA_fnc_removePerFrameHandler;
				[_taskID, "FAILED"] call EFUNC(main,setTaskState);
				EGVAR(main,exitTimer) = true;
				((units _grp) + GVAR(defend_enemies) + [_truck]) call EFUNC(main,cleanup);
				TASK_APPROVAL(getPos _truck,TASK_AV * -1);
				TASK_EXIT;
			};

			if (diag_tickTime > _time + COUNTDOWN) exitWith {
				[_idPFH] call CBA_fnc_removePerFrameHandler;
			  	_truck setDamage 0;
			  	(group driver _truck) move ([getPos _truck,4000,5000] call EFUNC(main,findPosSafe));
				[_taskID, "SUCCEEDED"] call EFUNC(main,setTaskState);
				((units _grp) + GVAR(defend_enemies) + [_truck]) call EFUNC(main,cleanup);
				TASK_APPROVAL(getPos _truck,TASK_AV);
				TASK_EXIT;
			};

			{
				if (isNull _x) then {GVAR(defend_enemies) deleteAt _forEachIndex};
			} forEach GVAR(defend_enemies);

			if (random 1 < 0.25 && {count GVAR(defend_enemies) < _enemyCount}) then {
				_grp = [[getpos _truck,200,400] call EFUNC(main,findPosSafe),0,8,EGVAR(main,enemySide),false,1] call EFUNC(main,spawnGroup);
				GVAR(defend_enemies) append (units _grp);
				_wp = _grp addWaypoint [getpos _truck,30];
			};
		}, TASK_SLEEP, [_taskID,_truck,_grp,_enemyCount,diag_tickTime]] call CBA_fnc_addPerFrameHandler;
	};
}, TASK_SLEEP, [_taskID,_truck,_grp]] call CBA_fnc_addPerFrameHandler;