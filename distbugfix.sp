#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#include <colors>
#include <distbugfix/stocks>

#define EPSILON		0.000001
#define MAXEDGE		32.0
#define MAXSTRAFES	32
#define PREFIX		"{default}[{olive}GC{default}]"
#define PERCENT		"%%"
#define MAX_COOKIE_SIZE			32
#define FL_SETTINGS_OFF			0
#define FL_SETTINGS_ENABLED		(1 << 0)
#define FL_SETTINGS_STRAFESTATS	(1 << 1)

#include "distbugfix/globalvars.sp"
#include "distbugfix/helpers.sp"
#include "distbugfix/chatreporting.sp"
#include "distbugfix/clientprefs.sp"

public Plugin myinfo = 
{
	name = "Distance Bug Fix", 
	author = "GameChaos", 
	description = "Fixes longjump distance bug", 
	version = "1.02"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
}

public void OnPluginStart()
{
	g_fTickRate = 1.0 / GetTickInterval();
	RegConsoleCmd("sm_distbug", Command_Distbug);
	RegConsoleCmd("sm_strafestats", Command_StrafeStats);
	
	g_hMinJumpDistance = CreateConVar("gc_min_jump_distance", "225.0", "Minimum jump distance.", FCVAR_NOTIFY, true, 32.0, false, 0.0);
	g_fMinJumpDistance = GetConVarFloat(g_hMinJumpDistance);
	HookConVarChange(g_hMinJumpDistance, OnConvarChanged);
	
	g_hMaxJumpDistance = CreateConVar("gc_max_jump_distance", "305.0", "Maximum jump distance.", FCVAR_NOTIFY, true, 32.0, false, 0.0);
	g_fMaxJumpDistance = GetConVarFloat(g_hMaxJumpDistance);
	HookConVarChange(g_hMaxJumpDistance, OnConvarChanged);
	
	AutoExecConfig(true, "distbugfix");
	
	OnPluginStart_Clientprefs();
	if (g_bLateLoad)
	{
		for (int client = 1; client < MaxClients; client++)
		{
			OnClientCookiesCached(client);
		}
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
	
	g_fAirDistance[client] = 0.0;
	
	ResetStatStrafeVars(client);
}

public void OnClientCookiesCached(int client)
{
	OnClientCookiesCached_Clientprefs(client);
}

// ======
// ACTION
// ======

public Action Command_Distbug(int client, int args)
{
	g_iSettings[client] ^= FL_SETTINGS_ENABLED;
	SaveClientCookie(client, g_iSettings[client]);
	
	if (g_iSettings[client] & FL_SETTINGS_STRAFESTATS)
	{
		CPrintToChat(client, "%s Distbug has been %s", PREFIX, (g_iSettings[client] & FL_SETTINGS_ENABLED) ? "enabled. Type !strafestats to turn strafestats off." : "disabled.");
	}
	else
	{
		CPrintToChat(client, "%s Distbug has been %s", PREFIX, (g_iSettings[client] & FL_SETTINGS_ENABLED) ? "enabled. Type !strafestats to turn strafestats on." : "disabled.");
	}
	
	return Plugin_Handled;
}

public Action Command_StrafeStats(int client, int args)
{
	if (g_iSettings[client] & FL_SETTINGS_ENABLED)
	{
		g_iSettings[client] ^= FL_SETTINGS_STRAFESTATS;
		SaveClientCookie(client, g_iSettings[client]);
		CPrintToChat(client, "%s Strafe stats have been %s.", PREFIX, (g_iSettings[client] & FL_SETTINGS_STRAFESTATS) ? "turned on" : "turned off");
	}
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!IsPlayerAlive(client) || !IsValidClient(client) || !(g_iSettings[client] & FL_SETTINGS_ENABLED))
	{
		return Plugin_Continue;
	}
	
	g_bInAir[client] = (GetEntityMoveType(client) == MOVETYPE_WALK) && !(GetEntityFlags(client) & FL_ONGROUND);
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
			g_fAirDistance[client] = 0.0;
			g_iJumpFrame[client] = GetGameTickCount();
			g_fJumpPosition[client] = g_fPosition[client];
			g_fAirDistance[client] += GetVectorHorLength(g_fVelocity[client]) * GetTickInterval();
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

// ========
// SET VARS
// ========

void SetFailStatVars(int client)
{
	if (!(g_fPosition[client][2] > g_fJumpPosition[client][2]
	 && g_fPosition[client][2] <= g_fJumpPosition[client][2] - g_fVelocity[client][2] / g_fTickRate + EPSILON))
	{
		return;
	}
	
	g_fFailStatStrafeGain[client]		= g_fStatStrafeGain[client];
	g_fFailStatStrafeLoss[client]		= g_fStatStrafeLoss[client];
	g_fFailStatStrafeMax[client]		= g_fStatStrafeMax[client];
	g_fFailStatStrafeSync[client]		= g_fStatStrafeSync[client];
	g_fFailStatStrafeAirtime[client]	= g_fStatStrafeAirtime[client];
	g_fFailPos[client]					= g_fPosition[client];
	g_fFailVelocity[client]				= g_fVelocity[client];
	g_fFailAirDistance[client]			= g_fAirDistance[client] - GetVectorHorLength(g_fVelocity[client]) * GetTickInterval();
	g_iFailStatSync[client]				= g_iStatSync[client];
	g_iFailStatStrafeOverlap[client]	= g_iStatStrafeOverlap[client];
	g_iFailStatStrafeDead[client]		= g_iStatStrafeDead[client];
	g_iFailStatStrafeCount[client]		= g_iStatStrafeCount[client];
	g_iFailAirTime[client]				= g_iFramesInAir[client];
	g_iFailDeadAirTime[client]			= g_iDeadAirtime[client];
	g_iFailOverlap[client]				= g_iFramesOverlapped[client];
}

// =========
// IMPORTANT
// =========
void OnPlayerInAir(int client, int &buttons, float vel[3])
{
	g_iFramesOnGround[client] = 0;
	g_iFramesInAir[client]++;
	
	if (!g_bValidJump[client])
	{
		return;
	}
	
	float fSpeed = GetVectorHorLength(g_fVelocity[client]);
	float fLastSpeed = GetVectorHorLength(g_fLastVelocity[client]);
	
	if (IsOverlapping(buttons))
		g_iFramesOverlapped[client]++;
	
	if (IsDeadAirtime(buttons))
		g_iDeadAirtime[client]++;
	
	if (IsStrafeSynced(fSpeed, fLastSpeed))
		g_iStatSync[client]++;
	
	CheckMaxHeight(client);
	CheckStrafeStats(client, buttons, vel, fSpeed, fLastSpeed);
	
	g_fAirDistance[client] += GetVectorHorLength(g_fVelocity[client]) * GetTickInterval();
	
	SetFailStatVars(client);
	
	CopyVector(g_fLastPosInAir[client], g_fLastLastPosInAir[client]);
	CopyVector(g_fVelocity[client], g_fLastVelocityInAir[client]);
	CopyVector(g_fPosition[client], g_fLastPosInAir[client]);
	CopyVector(vel, g_fLastVelInAir[client]);
}

void OnJumpLand(int client)
{
	// check rough offset
	if (g_fPosition[client][2] - g_fJumpPosition[client][2] > 2.0)
	{
		return;
	}
	
	float fJumpGround[3];
	float fLandGround[3];
	float fOffset = GetOffset(client, fJumpGround, fLandGround, false);
	
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
	
	float fAddedDistance;
	// failstat
	if (fOffset < 0.0)
	{
		float fFailDist = CalcFailDistance(g_fJumpPosition[client], g_fFailPos[client], g_fFailVelocity[client], fLandGround);
		fAddedDistance = GetVectorHorDistance(g_fFailPos[client], fLandGround);
		g_fFailAirDistance[client] += fAddedDistance;
		
		char szFailDist[40];
		FormatFailDist(szFailDist, sizeof(szFailDist), fFailDist);
		
		char szAirtime[32];
		FormatAirtime(szAirtime, sizeof(szAirtime), g_iFailAirTime[client]);
		
		char szSync[32];
		FormatSync(szSync, sizeof(szSync), g_iFailStatSync[client], g_iFailAirTime[client]);
		
		char szOverlap[32];
		FormatOverlap(szOverlap, sizeof(szOverlap), g_iFailOverlap[client]);
		
		char szDeadAirtime[32];
		FormatDeadAirtime(szDeadAirtime, sizeof(szDeadAirtime), g_iFailDeadAirTime[client]);
		
		char szDeviation[32];
		FormatDeviation(szDeviation, sizeof(szDeviation), fJumpGround, fLandGround);
		
		PrintFailStat(client, szFailDist, szEdge, szJumpHeight, szSync, szAirtime, szWRelease, szOverlap, szDeadAirtime, szDeviation);
	}
	// not failstat
	else
	{
		if (!IsOffset(fJumpGround[2], g_fPosition[client][2], EPSILON))
		{
			fAddedDistance = GetVectorHorDistance(g_fLastPosInAir[client], fLandGround);
			fAddedDistance -= GetVectorHorLength(g_fLastVelocity[client]) * GetTickInterval();
		}
		else
		{
			fAddedDistance = GetVectorHorDistance(g_fPosition[client], fLandGround);
		}
		g_fAirDistance[client] += fAddedDistance;
		float fDistance = CalcJumpDistance(g_fJumpPosition[client], fLandGround);
		
		if (!IsFloatInRange(fDistance, g_fMinJumpDistance, g_fMaxJumpDistance))
		{
			return;
		}
		
		char szDist[40];
		FormatDist(szDist, sizeof(szDist), fDistance);
		
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
		
		char szDeviation[32];
		FormatDeviation(szDeviation, sizeof(szDeviation), fJumpGround, fLandGround);
		
		PrintJumpstat(client, szDist, szEdge, szBlockdist, szJumpHeight, szSync, szAirtime, szWRelease, szOverlap, szDeadAirtime, szDeviation);
	}
	
	g_bValidJump[client] = false;
}

// Get z offset of current jump
float GetOffset(int client, float jumpGround[3], float landGround[3], bool optimised = true)
{
	TraceGround(client, g_fJumpPosition[client], jumpGround);
	
	// a tiny bit faster i guess
	if (optimised)
	{
		if (!TraceGround(client, g_fPosition[client], landGround))
		{
			return -99999.9;
		}
	}
	else
	{
		float fTempPos[3];
		bool bBugged;
		if (!IsOffset(g_fPosition[client][2], g_fJumpPosition[client][2], EPSILON))
		{
			CopyVector(g_fLastPosInAir[client], fTempPos);
			bBugged = true;
		}
		else
		{
			CopyVector(g_fPosition[client], fTempPos);
			bBugged = false;
		}
		
		if (!TraceLandPos(client, fTempPos, g_fLastVelocity[client], landGround, bBugged))
		{
			return -99999.9;
		}
	}
	
	return landGround[2] - jumpGround[2];
}

float GetBlockDist(int client, float position[3], float jumpPosition[3])
{
	float fBlockDist;
	float fEndEdge[3];
	float fStartEdge[3];
	int iBlockDir = BlockDirection(jumpPosition, position);
	
	float fPos2[3];
	position[2] = jumpPosition[2];
	
	fPos2 = position;
	fPos2[2] = jumpPosition[2] + 1.0;
	fPos2[iBlockDir] += (jumpPosition[iBlockDir] - position[iBlockDir]) / 2.0;
	g_bBlock[client] = TraceBlock(fPos2, jumpPosition, fStartEdge);
	
	fPos2 = jumpPosition;
	fPos2[2] += 1.0;
	fPos2[iBlockDir] += (position[iBlockDir] - jumpPosition[iBlockDir]) / 2.0;
	g_bBlock[client] = TraceBlock(fPos2, position, fEndEdge);
	
	fBlockDist = FloatAbs(fEndEdge[iBlockDir] - fStartEdge[iBlockDir]) + 32.0625;
	if (fStartEdge[iBlockDir] - fPos2[iBlockDir] != 0.0)
	{
		g_fJEdge[client] = FloatAbs(jumpPosition[iBlockDir] - RoundFloat(fStartEdge[iBlockDir]));
	}
	else
	{
		g_fJEdge[client] = -1.0;
	}
	return fBlockDist;
}

// calculator

float CalcFailDistance(const float jumpPosition[3], const float position[3], const float velocity[3], float landPos[3])
{
	float fLinePoint[3];
	float fLineDirection[3];
	float fPlanePoint[3];
	
	CopyVector(position, fLinePoint);
	NormalizeVector(velocity, fLineDirection);
	CopyVector(jumpPosition, fPlanePoint);
	
	float fPlaneNormal[3];
	fPlaneNormal[2] = 1.0;
	
	lineIntersection(fPlanePoint, fPlaneNormal, fLinePoint, fLineDirection, landPos);
	
	return GetVectorHorDistance(jumpPosition, landPos) + 32.0;
}

float CalcJumpDistance(const float jumpPosition[3], const float landPosition[3])
{
	return GetVectorHorDistance(jumpPosition, landPosition) + 32.0;
}