
// stocks for distbugfix plugin

#if defined _distbugfix_stocks_included
	#endinput
#endif
#define _distbugfix_stocks_included

/**
 * Determines the point of intersection between a plane defined by a point and a normal vector and a line defined by a point and a direction vector.
 *
 * @param planePoint    A point on the plane.
 * @param planeNormal   The normal vector of the plane.
 * @param linePoint     A point on the line.
 * @param lineDirection The direction vector of the line.
 * @param result		The resultant vector.
 */
stock void lineIntersection(float planePoint[3], float planeNormal[3], float linePoint[3], float lineDirection[3], float result[3])
{
	if (GetVectorDotProduct(planeNormal, lineDirection) == 0)
	{
		return;
	}
	
	float t = (GetVectorDotProduct(planeNormal, planePoint)
			 - GetVectorDotProduct(planeNormal, linePoint))
			 / GetVectorDotProduct(planeNormal, lineDirection);
	
	ScaleVector(lineDirection, t);
	
	AddVectors(linePoint, lineDirection, result);
}

stock bool TraceLandPos(int client, float pos[3], float velocity[3], float result[3], float tickGravity)
{
	float mins[3];
	float maxs[3];
	
	float pos2[3];
	
	AddVectors(pos, velocity, pos2);
	
	velocity[2] -= tickGravity;
	
	GetClientMins(client, mins);
	GetClientMaxs(client, maxs);
	
	Handle trace = TR_TraceHullFilterEx(pos, pos2, mins, maxs, MASK_PLAYERSOLID, TraceEntityFilterPlayer);
	
	if (!TR_DidHit(trace))
	{
		CloseHandle(trace);
		return false;
	}
	
	TR_GetEndPosition(result, trace);
	CloseHandle(trace);
	
	return true;
}

stock int BlockDirection(float jumpoff[3], float position[3])
{
	return FloatAbs(position[1] - jumpoff[1]) > FloatAbs(position[0] - jumpoff[0]);
}

stock void TraceGround(int client, float pos[3], float result[3])
{
	float mins[3];
	float maxs[3];
	
	GetClientMins(client, mins);
	GetClientMaxs(client, maxs);
	
	float startpos[3];
	float endpos[3];
	
	startpos = pos;
	endpos = pos;
	
	startpos[2]++;
	endpos[2]--;
	
	Handle trace = TR_TraceHullFilterEx(startpos, endpos, mins, maxs, MASK_PLAYERSOLID, TraceEntityFilterPlayer);
	
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(result, trace);
	}
	CloseHandle(trace);
}

stock bool TraceBlock(float pos2[3], float position[3], float result[3])
{
	float mins[3] =  { -16.0, -16.0, -1.0 };
	float maxs[3] =  { 16.0, 16.0, 0.0 };
	
	Handle trace = TR_TraceHullFilterEx(pos2, position, mins, maxs, MASK_PLAYERSOLID, TraceEntityFilterPlayer);
	
	if(!TR_DidHit(trace))
	{
		CloseHandle(trace);
		return false;
	}
	
	TR_GetEndPosition(result, trace);
	CloseHandle(trace);
	
	return true;
}

stock bool IsOffset(float z1, float z2, float tolerance)
{
	return (FloatAbs(z1 - z2) > tolerance);
}

stock float GetVectorHorLength(const float vec[3])
{
	float tempVec[3];
	tempVec = vec;
	tempVec[2] = 0.0;
	
	return GetVectorLength(tempVec);
}

stock float GetVectorHorDistance(float x[3], float y[3])
{
	float x2[3];
	float y2[3];
	
	x2 = x;
	y2 = y;
	
	x2[2] = 0.0;
	y2[2] = 0.0;
	
	return GetVectorDistance(x2, y2);
}

stock bool IsValidClient(int client)
{
	return (client >= 0 && client <= MaxClients && IsValidEntity(client) && IsClientConnected(client) && IsClientInGame(client));
}

stock bool TraceEntityFilterPlayer(int entity, any data)
{
	return entity > MAXPLAYERS;
}

stock int abs(x)
{
   return x >= 0 ? x : -x;
}

stock bool IsOverlapping(int &buttons)
{
	return buttons & IN_MOVERIGHT && buttons & IN_MOVELEFT
}

stock bool IsStrafeSynced(float speed, float lastspeed)
{
	return speed > lastspeed;
}

stock bool IsDeadAirtime(int &buttons)
{
	return !(buttons & IN_MOVERIGHT) && !(buttons & IN_MOVELEFT);
}

stock bool CheckMaxSpeed(float speed, float lastspeed)
{
	return speed > lastspeed;
}

stock bool IsFailstat(float z1, float z2, float tolerance)
{
	return z1 < z2 && z1 > z2 - tolerance;
}

stock bool IsFloatInRange(float distance, float min, float max)
{
	return distance >= min && distance <= max;
}

public float NormaliseAngle(float angle)
{
	while (angle <= -180.0)
	{
		angle += 360.0;
	}
	
	while (angle > 180.0)
	{
		angle -= 360.0;
	}
	
	return angle;
} 