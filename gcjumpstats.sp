#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <colors>

#define PREFIX "\x01[\x05KZ\x01]"

int g_iFramesOnGround[MAXPLAYERS + 1];
int g_iFramesInAir[MAXPLAYERS + 1];
int g_iTicksOverlapped[MAXPLAYERS + 1];
int g_iNoKeys[MAXPLAYERS + 1];
bool g_bOn[MAXPLAYERS + 1] = false;
bool g_bPerf[MAXPLAYERS + 1] = false;
bool g_bJumpLastTick[MAXPLAYERS + 1] = true;
bool g_bLJ[MAXPLAYERS + 1] = false;
char g_sStrafeStats[MAXPLAYERS + 1][3][128];
char g_sWRelease[MAXPLAYERS + 1][3];
float g_fLJPosition[MAXPLAYERS + 1][3];
float g_fPre[MAXPLAYERS + 1];
float g_fLastSpeedInAir[MAXPLAYERS + 1][3];
float g_fLastPosInAir[MAXPLAYERS + 1][3];
float g_fTickRate;
float g_fMax[MAXPLAYERS + 1];
float g_fAirPathDistance[MAXPLAYERS + 1];
float g_flastLastPosInAir[MAXPLAYERS + 1][3];
float g_fAngles[MAXPLAYERS + 1][3];
float g_fLastAngles[MAXPLAYERS + 1][3];

public Plugin myinfo = 
{
	name = "DISTBUG", 
	author = "GameChaos", 
	description = "innit", 
	version = "0.1"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_distbug", Command_DistBug);
	g_fTickRate = 1 / GetTickInterval();
}

public Action Command_DistBug(int client, int args)
{
	g_bOn[client] = !g_bOn[client];
	return Plugin_Handled; 
}

public void OnClientConnected(int client)
{
	g_bOn[client] = false;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsValidClient(client) && IsPlayerAlive(client) && g_bOn[client])
	{
		if (GetEntityFlags(client) & FL_ONGROUND)
		{
			float oldpos[3];
			int jumpTime;
			GetClientAbsOrigin(client, oldpos);
			jumpTime = g_iFramesInAir[client];
			g_iFramesOnGround[client]++;
			g_iFramesInAir[client] = 0;
			
			if (buttons & IN_JUMP && g_bJumpLastTick[client] == false)
			{
				char buffer[3];
				if (!(buttons & IN_FORWARD))
				{
					Format(buffer, sizeof(buffer), "YES");
					g_sWRelease[client] = buffer;
				}
				else
				{
					Format(buffer, sizeof(buffer), "NO ");
					g_sWRelease[client] = buffer;
				}
			}
			
			if (g_iFramesOnGround[client] == 1)
			{
				float position[3];
				float speed[3];
				float pdistance;
				float pos[2];
				char string[300];
				
				GetClientAbsOrigin(client, position);
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", speed);
				speed[2] = g_fLastSpeedInAir[client][2] - 301.993377 / g_fTickRate;
				pdistance = CalcJumpDistance(client, g_fLastSpeedInAir[client], g_fTickRate, g_fLastPosInAir[client], g_fLJPosition[client], speed, position);
				pos = ExtendVector(position, g_fLastSpeedInAir[client], g_fTickRate, g_fLastPosInAir[client], speed, g_fLJPosition[client]);
				g_fAirPathDistance[client] += CalcDistance(FloatAbs(g_fLastPosInAir[client][0] - pos[0]), FloatAbs(g_fLastPosInAir[client][1] - pos[1]));
				
				FormatEx(string, sizeof(string), "[KZ] %f units! \
				(%f airtime dist) \
				[%i Airtime \
				| -W %s \
				| %f Pre \
				| %i Overlap \
				| Dead airtime(-overlap): %i \
				| %f(%f) max]"\
				, pdistance\
				, g_fAirPathDistance[client] + 32.0\
				, jumpTime\
				, g_sWRelease[client]\
				, g_fPre[client]\
				, g_iTicksOverlapped[client]\
				, g_iNoKeys[client]\
				, g_fMax[client]\
				, g_fMax[client] - g_fPre[client]);
				CPrintToChat(client, "%s{grey} LJ: %.4f units [{lime}%i{grey} Airtime | -W %s | {lime}%.3f{grey} Pre | %i Overlap | {lime}%i{grey}({lime}%i{grey}) max]", PREFIX, pdistance, jumpTime, g_sWRelease[client], g_fPre[client], g_iTicksOverlapped[client], RoundToNearest(g_fMax[client]), RoundToNearest(g_fMax[client] - g_fPre[client]));
				PrintToConsole(client, string);
				//PrintToConsole(client, "%s\n%s\n%s\n ", g_sStrafeStats[client][0], g_sStrafeStats[client][1], g_sStrafeStats[client][2]);
				
				g_sStrafeStats[client][0] = "";
				g_sStrafeStats[client][1] = "";
				g_sStrafeStats[client][2] = "";
				g_iNoKeys[client] = 0;
				g_iTicksOverlapped[client] = 0;
				g_fMax[client] = 0.0;
				g_fAirPathDistance[client] = 0.0;
				g_bLJ[client] = false;
				
				if (buttons & IN_JUMP && g_bJumpLastTick[client] == false)g_bPerf[client] = true;
				else
				{
					g_bPerf[client] = false;
				}
			}
			float vec[3];
			
			GetClientAbsOrigin(client, g_fLJPosition[client]);
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", vec);
			
			g_bLJ[client] = true;
			g_fPre[client] = SquareRoot(FloatAbs((vec[0] * vec[0]) + (vec[1] * vec[1])))
			g_iTicksOverlapped[client] = 0;
			g_iNoKeys[client] = 0;
		}
		else if (GetEntityMoveType(client) != MOVETYPE_NOCLIP && GetEntityMoveType(client) != MOVETYPE_LADDER)
		{
			g_iFramesOnGround[client] = 0;
			g_iFramesInAir[client]++;
			
			GetClientAbsOrigin(client, g_fLastPosInAir[client]);
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", g_fLastSpeedInAir[client]);
			GetClientEyeAngles(client, g_fAngles[client]);
			
			if (g_iFramesInAir[client] == 1)
			{
				g_fAirPathDistance[client] += CalcDistance(g_fLastPosInAir[client][0] - g_fLJPosition[client][0], g_fLastPosInAir[client][1] - g_fLJPosition[client][1]);
			}
			else
			{
				g_fAirPathDistance[client] += CalcDistance(g_fLastPosInAir[client][0] - g_flastLastPosInAir[client][0], g_fLastPosInAir[client][1] - g_flastLastPosInAir[client][1]);
			}
			
			if (CalcDistance(g_fLastSpeedInAir[client][0], g_fLastSpeedInAir[client][1]) > g_fMax[client] && g_bLJ[client] == true)
			{
				g_fMax[client] = CalcDistance(g_fLastSpeedInAir[client][0], g_fLastSpeedInAir[client][1]);
			}
			
			if (buttons & IN_MOVERIGHT && buttons & IN_MOVELEFT)g_iTicksOverlapped[client]++;
			if (!(buttons & IN_MOVERIGHT) && !(buttons & IN_MOVELEFT))g_iNoKeys[client]++;
			GetClientAbsOrigin(client, g_flastLastPosInAir[client]);
			GetClientEyeAngles(client, g_fLastAngles[client]);
		}
		if (IsValidJump(client))g_bLJ[client] = false;
		
		g_bJumpLastTick[client] = !!(buttons & IN_JUMP);
	}
	return Plugin_Changed;
}

stock float CalcJumpDistance(int client, float LastSpeedInAir[3], float TickRate, float LastPosInAir[3], float JumpPosition[3], float speed[3], float position[3])
{
	//client, speed before landing, tickrate, position before landing, jumpoff position, current speed, current position
	float pos[2];
	float px;
	float py;
	
	pos = ExtendVector(position, LastSpeedInAir, TickRate, LastPosInAir, speed, JumpPosition);
	px = FloatAbs(JumpPosition[0] - pos[0]);
	py = FloatAbs(JumpPosition[1] - pos[1]);
	return (CalcDistance(px, py) + 32.0);
}

stock bool IsValidClient(client)
{
	return (client >= 1 && client <= MaxClients && IsValidEntity(client) && IsClientConnected(client) && IsClientInGame(client));
}

stock float ExtendVector(float position[3], float LastSpeedInAir[3], float TickRate, float LastPosInAir[3], float speed[3], float LJPos[3])
{
	//current position, speed on previous tick, tickrate, last position in air, current speed, jumpoff position
	float distMultiplier;
	float distMultiplierNB;
	float pos[2];
	
	distMultiplier = FloatAbs((LastPosInAir[2] - LJPos[2]) / (LastSpeedInAir[2] / TickRate));
	distMultiplierNB = FloatAbs((position[2] - LJPos[2]) / (speed[2] / TickRate));
	
	if (position[2] == LJPos[2])
	{
		pos[0] = LastPosInAir[0] + (LastSpeedInAir[0] / TickRate * distMultiplier);
		pos[1] = LastPosInAir[1] + (LastSpeedInAir[1] / TickRate * distMultiplier);
	}
	else
	{
		pos[0] = position[0] + (speed[0] / TickRate * distMultiplierNB);
		pos[1] = position[1] + (speed[1] / TickRate * distMultiplierNB);
	}
	//pos[0] = LastPosInAir[0] + (LastSpeedInAir[0] / TickRate * distMultiplier);
	//pos[1] = LastPosInAir[1] + (LastSpeedInAir[1] / TickRate * distMultiplier);
	return pos;
}

stock bool IsValidJump(client)
{
	float flVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecBaseVelocity", flVelocity);
	if (g_iFramesInAir[client] > 0 && (GetEntityMoveType(client) == MOVETYPE_LADDER || GetEntityMoveType(client) == MOVETYPE_NOCLIP))
	{
		return false;
	}
	else if (flVelocity[0] != 0.0 || flVelocity[1] != 0.0 || flVelocity[2] != 0.0)
	{
		return true;
	}
	else
	{
		return false;
	}
}

stock float CalcDistance(float x, float y)
{
	return SquareRoot(x * x + y * y);
}