#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// 3rd party libs
#include <colors>

#define MAXOFFSET	0.03125
#define MAXDIST		305.0
#define MINDIST		225.0
#define PREFIX "\x01[\x05GC\x01]"

float g_fJumpPosition[MAXPLAYERS + 1][3];
float g_fLastPosInAir[MAXPLAYERS + 1][3];
float g_fLastLastPosInAir[MAXPLAYERS + 1][3];
float g_fLastSpeedInAir[MAXPLAYERS + 1][3];
float g_fTickRate;
float g_fTickGravity = 800.0;
int g_iFramesOnGround[MAXPLAYERS + 1];
bool g_bLastJump[MAXPLAYERS + 1] = false;
bool g_bJumpEnd[MAXPLAYERS + 1] = false;
bool g_bDistbug[MAXPLAYERS + 1] = false;
bool g_bBind[MAXPLAYERS + 1] = false;
bool g_bLastDuck[MAXPLAYERS + 1] = false;
bool g_bBugged[MAXPLAYERS + 1] = false;
bool g_bW[MAXPLAYERS + 1] = false;

// FOR HEIGHT calc
float g_fMaxHeight[MAXPLAYERS + 1];
int g_iFramesInAir[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Distance Bug Fix", 
	author = "GameChaos", 
	description = "Fixes longjump distance bug", 
	version = "0.2"
};

public void OnPluginStart()
{
	g_fTickRate = 1 / GetTickInterval();
	RegConsoleCmd("sm_distbug", Command_Distbug);
	HookEvent("player_jump", Event_OnJump_Pre, EventHookMode_Pre);
}

public void OnConfigsExecuted()
{
	Handle gravity = FindConVar("sv_gravity");
	if (gravity != INVALID_HANDLE)
	{
		g_fTickGravity = GetConVarFloat(gravity) / g_fTickRate;
	}
	CloseHandle(gravity);
}

// Hook pre jump to reset height
public Action Event_OnJump_Pre(Handle event, const char[] name, bool broadcast)
{
	int client;
	client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidClient(client) && g_bDistbug[client])
	{
		g_fMaxHeight[client] = -99999.0;
	}
}

public Action Command_Distbug(int client, int args)
{
	g_bDistbug[client] = !g_bDistbug[client];
	CPrintToChat(client, "%s Distbug has been %s.", PREFIX, g_bDistbug[client] ? "enabled" : "disabled");
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsValidClient(client) && g_bDistbug[client])
	{
		if (GetEntityFlags(client) & FL_ONGROUND)
		{
			g_iFramesOnGround[client]++;
			
			if (g_iFramesOnGround[client] > 1 && buttons & IN_JUMP && !g_bLastJump[client])
			{
				GetClientAbsOrigin(client, g_fJumpPosition[client]);
				g_bJumpEnd[client] = false;
				g_bBind[client] = (buttons & IN_JUMP && !g_bLastJump[client]) && (buttons & IN_DUCK && !g_bLastDuck[client]);
				g_bW[client] = !(buttons & IN_FORWARD);
			}
			else if (!g_bJumpEnd[client])
			{
				JumpLand(client);
			}
			g_iFramesInAir[client] = 0;
		}
		else if (GetEntityMoveType(client) != MOVETYPE_NOCLIP && GetEntityMoveType(client) != MOVETYPE_LADDER)
		{
			g_iFramesOnGround[client] = 0;
			g_iFramesInAir[client]++;
			g_fLastLastPosInAir[client] = g_fLastPosInAir[client];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", g_fLastSpeedInAir[client]);
			GetClientAbsOrigin(client, g_fLastPosInAir[client]);
		}
		g_bLastJump[client] = !!(buttons & IN_JUMP);
		g_bLastDuck[client] = !!(buttons & IN_DUCK);

		// track height
		if (!g_bJumpEnd[client])
		{
			float origin[3];
			GetClientAbsOrigin(client, origin);
			if (GetEntityFlags(client) & FL_DUCKING)origin[2] -= 9; // normalises the height so you don't get 66.0 height or whatever
			if (origin[2] > g_fMaxHeight[client])
			{
				g_fMaxHeight[client] = origin[2];
			}
		}
	}
	return Plugin_Changed;
}

public JumpLand(int client)
{
	float speed;
	float position[3];
	float distance;
	float jumpground[3];
	float landground[3];
	float jumpHeight;
	int airTime = g_iFramesInAir[client];
	
	GetClientAbsOrigin(client, position)
	speed = GetEntPropFloat(client, Prop_Data, "m_flFallVelocity");
	
	TraceGround(client, g_fJumpPosition[client], jumpground);
	TraceGround(client, position, landground);
	
	if (CheckOffset(jumpground[2], landground[2]))
	{
		g_bJumpEnd[client] = true;
		return;
	}
	
	jumpHeight = GetHeight(client);
				
	distance = CalcJumpDistance(client, g_fLastSpeedInAir[client], g_fTickRate, g_fLastPosInAir[client], g_fLastLastPosInAir[client], g_fJumpPosition[client], speed, position);
	
	if (distance >= MINDIST && distance <= MAXDIST)
	{
		CPrintToChat(client, "%s{grey} %sRealDist: {default}%f{grey} [{lime}%.4f{grey} Height | {lime}%i{grey} Airtime | -W: %s]", PREFIX, g_bBugged[client] ? "(BUGGED) " : "", distance, jumpHeight, airTime, g_bW[client] ? "{green}YE{grey}" : "{darkred}NO{grey}");
		PrintToConsole(client, "[GC] %sRealDist: %f [%.4f Height | %i Airtime | -W: %s]", g_bBugged[client] ? "(BUGGED) " : "", distance, jumpHeight, airTime, g_bW[client] ? "YE" : "NO");
	}
	g_bJumpEnd[client] = true;
}

float GetHeight(int client)
{
	//GetHeight
	//Reference (aka copied): https://bitbucket.org/kztimerglobalteam/kztimerglobal/src/61fc18f23fe347a3dfb761440684d67380323179/scripting/kztimerGlobal/jumpstats.sp?at=master&fileviewer=file-view-default#jumpstats.sp-553
	if (g_fJumpPosition[client][2] < 0.0 && g_fMaxHeight[client] > 0.0)
	{
		return FloatAbs(g_fJumpPosition[client][2]) + g_fMaxHeight[client];
	}
	else
	{
		if (g_fJumpPosition[client][2] > 0.0 && g_fMaxHeight[client] < 0.0)
		{
			return FloatAbs(g_fMaxHeight[client] + g_fJumpPosition[client][2]);
		}
		else if (FloatAbs(g_fJumpPosition[client][2]) > FloatAbs(g_fMaxHeight[client]))
		{
			return FloatAbs(g_fJumpPosition[client][2]) - FloatAbs(g_fMaxHeight[client]);
		}
		else
		{
			return FloatAbs(g_fMaxHeight[client]) - FloatAbs(g_fJumpPosition[client][2]);
		}
	}
}

stock float CalcJumpDistance(int client, float LastSpeedInAir[3], float TickRate, float LastPosInAir[3], float LastLastPosInAir[3], float JumpPosition[3], float speed, float position[3])
{
	float distance;
	float tickdistx;
	float tickdisty;
	float tickspeedz;
	float groundoffset;
	float multiplier;
	
	if (position[2] == JumpPosition[2])
	{
		groundoffset	= JumpPosition[2] - LastPosInAir[2];
		tickspeedz		= FloatAbs(LastSpeedInAir[2] + g_fTickGravity) / g_fTickRate;
		multiplier		= (tickspeedz - groundoffset) / tickspeedz;
		tickdistx		= FloatAbs(LastLastPosInAir[0] - LastPosInAir[0]) * multiplier;
		tickdisty		= FloatAbs(LastLastPosInAir[1] - LastPosInAir[1]) * multiplier;
		distance = CalcDistance(FloatAbs(JumpPosition[0] - LastLastPosInAir[0]) + tickdistx, FloatAbs(JumpPosition[1] - LastLastPosInAir[1]) + tickdisty);
		g_bBugged[client] = true;
	}
	else
	{
		groundoffset	= JumpPosition[2] - position[2];
		tickspeedz		= FloatAbs(LastSpeedInAir[2]) / g_fTickRate;
		multiplier		= (tickspeedz - groundoffset) / tickspeedz;
		tickdistx		= FloatAbs(LastPosInAir[0] - position[0]) * multiplier;
		tickdisty		= FloatAbs(LastPosInAir[1] - position[1]) * multiplier;
		distance = CalcDistance(FloatAbs(JumpPosition[0] - LastPosInAir[0]) + tickdistx, FloatAbs(JumpPosition[1] - LastPosInAir[1]) + tickdisty);
		g_bBugged[client] = false;
	}
	
	return distance + 32;
}

stock void TraceGround(int client, float pos[3], float result[3])
{
	float mins[3] =  { -16.0, -16.0, -1.0 };
	float maxs[3] =  { 16.0, 16.0, 0.0 };
	float startpos[3];
	float endpos[3];
	
	startpos = pos;
	endpos = pos;
	startpos[2] += 1;
	endpos[2] -= 1;
	
	Handle trace = TR_TraceHullFilterEx(startpos, endpos, mins, maxs, MASK_SHOT, TraceEntityFilterPlayer);
	
	if(TR_DidHit(trace))
	{				
		TR_GetEndPosition(result, trace);
	}
	CloseHandle(trace); 
}

stock bool CheckOffset(float z1, float z2)
{
	return (!(z1 == z2) || FloatAbs(z1 - z2) > MAXOFFSET * 2);
}

stock float CalcDistance(float x, float y)
{
	return SquareRoot(Pow(FloatAbs(x), 2.0) + Pow(FloatAbs(y), 2.0));
}

stock bool IsValidClient(int client)
{
	return (client >= 1 && client <= MaxClients && IsValidEntity(client) && IsClientConnected(client) && IsClientInGame(client));
}

public bool TraceEntityFilterPlayer(int entity, any data)
{
	return entity > MAXPLAYERS;
}