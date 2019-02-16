#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <colors>
#include <distbugfix/stocks>

#define EPSILON		0.000001
#define MAXEDGE		32.0
#define MAXSTRAFES	32
#define PREFIX		"\x01[\x05GC\x01]"
#define PERCENT		"%%"

#include "distbugfix/globalvars.sp"
#include "distbugfix/helpers.sp"
#include "distbugfix/chatreporting.sp"

public Plugin myinfo = 
{
	name = "Distance Bug Fix", 
	author = "GameChaos", 
	description = "Fixes longjump distance bug", 
	version = "1.0"
};

public void OnPluginStart()
{
	g_fTickRate = 1 / GetTickInterval();
	RegConsoleCmd("sm_distbug", Command_Distbug);
	RegConsoleCmd("sm_strafestats", Command_StrafeStats);
	
	g_hMinJumpDistance = CreateConVar("gc_min_jump_distance", "225.0", "Minimum jump distance.", FCVAR_NOTIFY, true, 32.0, false, 0.0);
	g_fMinJumpDistance = GetConVarFloat(g_hMinJumpDistance);
	HookConVarChange(g_hMinJumpDistance, OnConvarChanged);
	
	g_hMaxJumpDistance = CreateConVar("gc_max_jump_distance", "305.0", "Maximum jump distance.", FCVAR_NOTIFY, true, 32.0, false, 0.0);
	g_fMaxJumpDistance = GetConVarFloat(g_hMaxJumpDistance);
	HookConVarChange(g_hMaxJumpDistance, OnConvarChanged);
	
	AutoExecConfig(true, "distbugfix");
	
	g_hGravity = FindConVar("sv_gravity");
	HookConVarChange(g_hGravity, OnConvarChanged);
	
	if (g_hGravity != INVALID_HANDLE)
	{
		g_fTickGravity = GetConVarFloat(g_hGravity) / g_fTickRate;
	}
}

public void OnConvarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if(convar == g_hMinJumpDistance)
	{
		g_fMinJumpDistance = StringToFloat(newValue[0]);
	}
	
	if(convar == g_hMaxJumpDistance)
	{
		g_fMaxJumpDistance = StringToFloat(newValue[0]);
	}
	
	
	if(convar == g_hGravity)
	{
		g_fTickGravity = StringToFloat(newValue[0]) / g_fTickRate;
	}
}

public void OnClientConnected(int client)
{
	g_fLastVelInAir[client] = NULL_VECTOR;
	g_fLastVelocity[client] = NULL_VECTOR;
	g_fLastVelocityInAir[client] = NULL_VECTOR;
	g_fLastPosInAir[client] = NULL_VECTOR;
	g_fLastLastPosInAir[client] = NULL_VECTOR;
	
	g_iFramesInAir[client] = 0;
	g_iFramesOnGround[client] = 0;
	g_iFramesOverlapped[client] = 0;
	
	g_iDeadAirtime[client] = 0;
	g_iWReleaseFrame[client] = 0;
	g_iJumpFrame[client] = 0;
	
	g_iLastButtons[client] = 0;
	
	g_bValidJump[client] = false;
	g_bDistbug[client] = false;
	g_bStrafeStats[client] = false;
	
	ResetStatStrafeVars(client);
}

// ACTION

public Action Command_Distbug(int client, int args)
{
	g_bDistbug[client] = !g_bDistbug[client];
	if (g_bStrafeStats[client])
	{
		CPrintToChat(client, "%s Distbug has been %s", PREFIX, g_bDistbug[client] ? "enabled. Type !strafestats to turn strafestats off." : "disabled.");
	}
	else
	{
		CPrintToChat(client, "%s Distbug has been %s", PREFIX, g_bDistbug[client] ? "enabled. Type !strafestats to turn strafestats on." : "disabled.");
	}
	return Plugin_Handled;
}

public Action Command_StrafeStats(int client, int args)
{
	if (g_bDistbug[client])
	{
		g_bStrafeStats[client] = !g_bStrafeStats[client];
		CPrintToChat(client, "%s Strafe stats have been %s.", PREFIX, g_bStrafeStats[client] ? "turned on" : "turned off");
	}
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!IsPlayerAlive(client) || !IsValidClient(client) || !g_bDistbug[client])
	{
		return Plugin_Continue;
	}
	
	g_bInAir[client] = GetEntityMoveType(client) != MOVETYPE_NOCLIP && GetEntityMoveType(client) != MOVETYPE_LADDER;
	GetClientAbsOrigin(client, g_fPosition[client])
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", g_fVelocity[client]);
	
	if (!(buttons & IN_FORWARD) && g_iLastButtons[client] & IN_FORWARD)
	{
		g_iWReleaseFrame[client] = GetGameTickCount();
	}
	
	if (GetEntityFlags(client) & FL_ONGROUND)
	{
		g_iFramesOnGround[client]++;
		
		if (g_iFramesOnGround[client] > 1 && buttons & IN_JUMP && !(g_iLastButtons[client] & IN_JUMP))
		{
			g_bValidJump[client] = true;
			g_fMaxHeight[client] = -99999.0;
			g_iJumpFrame[client] = GetGameTickCount();
			g_fJumpPosition[client] = g_fPosition[client];
		}
		if (g_bValidJump[client] && g_iFramesOnGround[client] == 1)
		{
			OnJumpLand(client);
			
			ResetStatStrafeVars(client);
			g_fLastVelInAir[client] = NULL_VECTOR;
			g_bBlock[client] = false;
		}
		g_iFramesInAir[client] = 0;
		g_iDeadAirtime[client] = 0;
		g_iFramesOverlapped[client] = 0;
	}
	else if (g_bInAir[client])
	{
		OnPlayerInAir(client, buttons, vel);
	}
	
	// LAST
	g_fLastVelocity[client] = g_fVelocity[client];
	g_iLastButtons[client] = buttons;
	return Plugin_Changed;
}


// var setter

void ResetStatStrafeVars(int client)
{
	for (int i = 0; i < MAXSTRAFES; i++)
	{
		g_fStatStrafeGain[client][i] = 0.0;
		g_fStatStrafeLoss[client][i] = 0.0;
		g_fStatStrafeMax[client][i] = 0.0;
		g_fStatStrafeSync[client][i] = 0.0;
		g_fStatStrafeAirtime[client][i] = 0.0;
		g_iStatStrafeOverlap[client][i] = 0;
		g_iStatStrafeDead[client][i] = 0;
	}
	g_iStatStrafeCount[client] = 0;
	g_iStatSync[client] = 0;
}

// set vars

void SetFailStatVars(int client)
{
	if (!IsFailstat(g_fPosition[client][2], g_fJumpPosition[client][2], -g_fVelocity[client][2] / g_fTickRate + 1.0))
	{
		return;
	}
	
	g_fFailStatStrafeGain[client] = g_fStatStrafeGain[client];
	g_fFailStatStrafeLoss[client] = g_fStatStrafeLoss[client];
	g_fFailStatStrafeMax[client] = g_fStatStrafeMax[client];
	g_fFailStatStrafeSync[client] = g_fStatStrafeSync[client];
	g_fFailStatStrafeAirtime[client] = g_fStatStrafeAirtime[client];
	g_fFailPos[client] = g_fPosition[client];
	g_fFailVelocity[client] = g_fVelocity[client];
	g_iFailStatSync[client] = g_iStatSync[client];
	g_iFailStatStrafeOverlap[client] = g_iStatStrafeOverlap[client];
	g_iFailStatStrafeDead[client] = g_iStatStrafeDead[client];
	g_iFailStatStrafeCount[client] = g_iStatStrafeCount[client];
	g_iFailAirTime[client] = g_iFramesInAir[client];
	g_iFailDeadAirTime[client] = g_iDeadAirtime[client];
	g_iFailOverlap[client] = g_iFramesOverlapped[client];
}

// important

void OnPlayerInAir(int client, int &buttons, float vel[3])
{
	g_iFramesOnGround[client] = 0;
	g_iFramesInAir[client]++;
	
	if (!g_bValidJump[client])
	{
		return;
	}
	
	if (IsFailstat(g_fPosition[client][2], g_fJumpPosition[client][2], -g_fVelocity[client][2] / g_fTickRate + 1.0))
	{
		float angles[3];
		GetClientAbsAngles(client, angles);
	}
	
	float speed = GetVectorHorLength(g_fVelocity[client]);
	float lastspeed = GetVectorHorLength(g_fLastVelocity[client]);
	
	if (IsOverlapping(buttons))
		g_iFramesOverlapped[client]++;
	
	if (IsDeadAirtime(buttons))
		g_iDeadAirtime[client]++;
	
	if (IsStrafeSynced(speed, lastspeed))
		g_iStatSync[client]++;
	
	CheckMaxHeight(client);
	CheckStrafeStats(client, buttons, vel, speed, lastspeed);
	
	SetFailStatVars(client);
	
	g_fLastLastPosInAir[client] = g_fLastPosInAir[client];
	g_fLastVelocityInAir[client] = g_fVelocity[client];
	g_fLastPosInAir[client] = g_fPosition[client];
	g_fLastVelInAir[client] = vel;
}

void OnJumpLand(int client)
{
	float fOffset = GetOffset(client, false);
	
	if (fOffset > EPSILON)
	{
		return;
	}
	
	float fBlockDist = GetBlockDist(client, g_fPosition[client], g_fJumpPosition[client]);
	
	// jump start strings
	char szJumpHeight[32];
	FormatHeight(client, szJumpHeight, sizeof(szJumpHeight));
	
	char szWRelease[32];
	FormatWRelease(client, szWRelease, sizeof(szWRelease));
	
	char szEdge[32];
	FormatEdge(client, szEdge, sizeof(szEdge));
	
	if (fOffset < -EPSILON)
	{
		float failDist = CalcFailDistance(g_fJumpPosition[client], g_fFailPos[client], g_fFailVelocity[client]);
		
		char szFailDist[32];
		FormatFailDist(szFailDist, sizeof(szFailDist), failDist);
		
		char szAirtime[32];
		FormatAirtime(szAirtime, sizeof(szAirtime), g_iFailAirTime[client]);
		
		char szSync[32];
		FormatSync(szSync, sizeof(szSync), g_iFailStatSync[client], g_iFailAirTime[client]);
		
		char szBlockdist[32];
		FormatBlockDistance(szBlockdist, sizeof(szBlockdist), fBlockDist);
		
		char szOverlap[32];
		FormatOverlap(szOverlap, sizeof(szOverlap), g_iFramesOverlapped[client]);
		
		char szDeadAirtime[32];
		FormatDeadAirtime(szDeadAirtime, sizeof(szDeadAirtime), g_iDeadAirtime[client]);
		
		PrintFailStat(client, szFailDist, szEdge, szBlockdist, szJumpHeight, szSync, szAirtime, szWRelease, szOverlap, szDeadAirtime);
	}
	else
	{
		float distance = CalcJumpDistance(client);
		
		if (!IsFloatInRange(distance, g_fMinJumpDistance, g_fMaxJumpDistance))
		{
			return;
		}
		
		char szDist[32];
		FormatDist(szDist, sizeof(szDist), distance);
		
		char szAirtime[32];
		FormatAirtime(szAirtime, sizeof(szAirtime), g_iFramesInAir[client]);
		
		char szSync[32];
		FormatSync(szSync, sizeof(szSync), g_iStatSync[client], g_iFramesInAir[client]);
		
		char szBlockdist[32];
		FormatBlockDistance(szBlockdist, sizeof(szBlockdist), fBlockDist);
		
		char szOverlap[32];
		FormatOverlap(szOverlap, sizeof(szOverlap), g_iFramesOverlapped[client]);
		
		char szDeadAirtime[32];
		FormatDeadAirtime(szDeadAirtime, sizeof(szDeadAirtime), g_iDeadAirtime[client]);
		
		PrintJumpstat(client, szDist, szEdge, szBlockdist, szJumpHeight, szSync, szAirtime, szWRelease, szOverlap, szDeadAirtime);
	}
	
	g_bValidJump[client] = false;
}

/*
 * Get z offset of current jump
 */

float GetOffset(int client, bool optimised = true)
{
	float jumpground[3];
	float landground[3];
	
	TraceGround(client, g_fJumpPosition[client], jumpground);
	
	if (optimised)
	{
		TraceGround(client, g_fPosition[client], landground);
	}
	else
	{
		float tempPos[3];
		float tickGravity;
		
		tempPos = g_fPosition[client];
		
		if (!IsFloatInRange(g_fPosition[client][2] - g_fJumpPosition[client][2], -EPSILON, EPSILON))
		{
			tickGravity = g_fTickGravity;
			tempPos = g_fLastPosInAir[client];
		}
		
		TraceLandPos(client, tempPos, g_fLastVelocity[client], landground, tickGravity);
	}
	
	return landground[2] - jumpground[2];
}

float GetBlockDist(int client, float position[3], float jumpPosition[3])
{
	float blockdist;
	float endEdge[3];
	float startEdge[3];
	int blockDir = BlockDirection(jumpPosition, position);
	
	float pos2[3];
	position[2] = jumpPosition[2];
	
	pos2 = position;
	pos2[2] = jumpPosition[2] + 1.0;
	pos2[blockDir] += (jumpPosition[blockDir] - position[blockDir]) / 2.0;
	g_bBlock[client] = TraceBlock(pos2, jumpPosition, startEdge);
	
	pos2 = jumpPosition;
	pos2[2] += 1.0;
	pos2[blockDir] += (position[blockDir] - jumpPosition[blockDir]) / 2.0;
	g_bBlock[client] = TraceBlock(pos2, position, endEdge);
	
	blockdist = FloatAbs(endEdge[blockDir] - startEdge[blockDir]) + 32.0625;
	if (startEdge[blockDir] - pos2[blockDir] != 0.0)
	{
		g_fJEdge[client] = FloatAbs(jumpPosition[blockDir] - RoundFloat(startEdge[blockDir]));
	}
	else
	{
		g_fJEdge[client] = -1.0;
	}
	return blockdist;
}

// calculator

float CalcFailDistance(float jumpPosition[3], float position[3], float velocity[3])
{
	float linePoint[3];
	float lineDirection[3];
	float planePoint[3];
	float planeNormal[3];
	float realLandingPos[3];
	
	linePoint = position;
	lineDirection = velocity;
	
	planePoint = jumpPosition;
	
	planeNormal[2] = 1.0;
	
	lineIntersection(planePoint, planeNormal, linePoint, lineDirection, realLandingPos);
	
	return GetVectorHorDistance(jumpPosition, realLandingPos) + 32.0;
}

// calculator

float CalcJumpDistance(int client)
{
	float realLandPos[3];
	
	// is jump bugged?
	if (!IsOffset(g_fPosition[client][2], g_fJumpPosition[client][2], EPSILON))
	{
		if (TraceLandPos(client, g_fLastPosInAir[client], g_fLastVelocity[client], realLandPos, g_fTickGravity))
		{
			return GetVectorHorDistance(g_fJumpPosition[client], realLandPos) + 32.0;
		}
	}
	
	if (TraceLandPos(client, g_fPosition[client], g_fLastVelocity[client], realLandPos, 0.0))
	{
		return GetVectorHorDistance(g_fJumpPosition[client], realLandPos) + 32.0;
	}
	return -1.0;
}