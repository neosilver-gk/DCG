/*
Author:
Nicholas Clark (SENSEI)

Description:
finds an interior house position outside a town

Arguments:
0: center position <ARRAY>
1: search distance <NUMBER>

Return:
array
__________________________________________________________________*/
#include "script_component.hpp"
#define EXPRESSION "(1 + houses)"
#define DIST worldSize*0.07

private ["_ret","_pos","_locations"];
params ["_anchor","_range"];

_ret = [];

{
	_pos = _x select 0;
	_locations = nearestLocations [_pos, ["NameVillage","NameCity","NameCityCapital"], DIST];
	if (_locations isEqualTo []) then {
		_ret = [_pos,500] call FUNC(findHousePos);
		if !(_ret isEqualTo []) exitWith {};
	};
} forEach (selectBestPlaces [_anchor,_range,EXPRESSION,70,10]);

_ret