#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#include <colors>
#include <gamechaos>

#pragma newdecls required
#pragma semicolon 1

#define CHAT_PREFIX			"{d}[{l}GC{d}]"
#define CHAT_SEPARATOR		"{g}|"
#define DISTBUG_VERSION		"1.1.0"

#define MAX_COOKIE_SIZE		32
#define MAX_EDGE			32.0
#define MAX_STRAFES			17

enum
{
	AXIS_X,
	AXIS_Y,
	AXIS_Z
}

enum Jumptype
{
	JUMPTYPE_INVALID,
	JUMPTYPE_LJ,
	JUMPTYPE_COUNT
}

enum (<<= 1)
{
	FL_SETTINGS_OFF = 1,
	FL_SETTINGS_ENABLED,
	FL_SETTINGS_STRAFESTATS
}

enum struct Jump
{
	Jumptype jumptype;
	float distance;
	float edge;
	float block;
	float prestrafe;
	float maxspeed;
	float airpath; // straightness of airpath
	float deviation;
	float height;
	float sync;
	int airtime;
	int wRelease;
	int overlap;
	int deadair;
	
	// tracking stuff
	int jumpTick;
	bool ljBug;
	bool failed;
	bool validJump;
	float realLandOrigin[3];
	
	// strafe things
	int strafes;
	float strafeSync[MAX_STRAFES];
	float strafeGain[MAX_STRAFES];
	float strafeLoss[MAX_STRAFES];
	float strafeMax[MAX_STRAFES];
	int strafeAirtime[MAX_STRAFES];
	int strafeOverlap[MAX_STRAFES];
	int strafeDeadair[MAX_STRAFES];
	float strafeAvgGain[MAX_STRAFES];
	
	void Reset()
	{
		this.strafes = 0;
		this.jumptype = JUMPTYPE_INVALID;
		this.distance = 0.0;
		this.edge = -1.0;
		this.block = 0.0;
		this.prestrafe = 0.0;
		this.maxspeed = 0.0;
		this.airpath = 0.0;
		this.deviation = 0.0;
		this.height = 0.0;
		this.sync = 0.0;
		this.airtime = 0;
		this.wRelease = 0;
		this.overlap = 0;
		this.deadair = 0;
		
		this.ljBug = false;
		this.jumpTick = 0;
		this.failed = false;
		this.validJump = false;
		this.realLandOrigin = NULL_VECTOR;
		
		for (int i; i < MAX_STRAFES; i++)
		{
			this.strafeSync[i] = 0.0;
			this.strafeGain[i] = 0.0;
			this.strafeLoss[i] = 0.0;
			this.strafeMax[i] = 0.0;
			this.strafeAirtime[i] = 0;
			this.strafeOverlap[i] = 0;
			this.strafeDeadair[i] = 0;
			this.strafeAvgGain[i] = 0.0;
		}
	}
}

enum struct PlayerData
{
	Jump jump;
	float origin[3];
	float velocity[3];
	float lastNoduckOrigin[3];
	float lastVelocity[3];
	float jumpOrigin[3];
	float jumpGround[3];
	float landGround[3];
	float vel[3];
	float lastVel[3];
	int framesOnGround;
	int buttons;
	int buttonReleased;
	int wReleaseTick;
	
	void Reset()
	{
		this.jump.Reset();
		this.origin = NULL_VECTOR;
		this.velocity = NULL_VECTOR;
		this.lastNoduckOrigin = NULL_VECTOR;
		this.lastVelocity = NULL_VECTOR;
		this.jumpOrigin = NULL_VECTOR;
		this.jumpGround = NULL_VECTOR;
		this.landGround = NULL_VECTOR;
		this.framesOnGround = 0;
		this.buttons = 0;
		this.buttonReleased = 0;
		this.wReleaseTick = 0;
	}
}

char g_szJumptypes[JUMPTYPE_COUNT][] = {
	"Invalid",
	"LJ",
};

bool g_bLateLoad;

ConVar g_cvMinJumpDistance;
ConVar g_cvMaxJumpDistance;
ConVar g_cvGravity;

#include "distbugfix/jumptracking.sp"
#include "distbugfix/clientprefs.sp"

public Plugin myinfo = 
{
	name = "Distance Bug Fix", 
	author = "GameChaos", 
	description = "Fixes longjump distance bug", 
	version = DISTBUG_VERSION,
	url = "https://bitbucket.org/GameChaos/distbug/src"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
}

public void OnPluginStart()
{
	OnPluginStart_Clientprefs();
	
	RegConsoleCmd("sm_distbug", Command_Distbug);
	RegConsoleCmd("sm_distbugversion", Command_Distbugversion);
	RegConsoleCmd("sm_strafestats", Command_StrafeStats);
	
	g_cvMinJumpDistance = CreateConVar("gc_min_jump_distance", "225.0", "Minimum jump distance.", FCVAR_NOTIFY, true, 32.0);
	g_cvMaxJumpDistance = CreateConVar("gc_max_jump_distance", "305.0", "Maximum jump distance.", FCVAR_NOTIFY, true, 32.0);
	
	AutoExecConfig(true, "distbugfix");
	
	g_cvGravity = FindConVar("sv_gravity");
	
	HookEvent("player_jump", EventPlayerJump);
}

public void OnClientCookiesCached(int client)
{
	OnClientCookiesCached_Clientprefs(client);
}

public void OnClientConnected(int client)
{
	OnClientConnected_Jumptracking(client);
}

public void EventPlayerJump(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	EventPlayerJump_Jumptracking(client);
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	OnPlayerRunCmdPost_JumpTracking(client, vel);
}

// ========
// Commands
// ========

public Action Command_Distbug(int client, int args)
{
	ToggleSetting(client, FL_SETTINGS_ENABLED);
	
	if (IsSettingEnabled(client, FL_SETTINGS_STRAFESTATS))
	{
		CPrintToChat(client, "%s Distbug has been %s", CHAT_PREFIX, IsSettingEnabled(client, FL_SETTINGS_ENABLED) ? "enabled. Type !strafestats to turn strafestats off." : "disabled.");
	}
	else
	{
		CPrintToChat(client, "%s Distbug has been %s", CHAT_PREFIX, IsSettingEnabled(client, FL_SETTINGS_ENABLED) ? "enabled. Type !strafestats to turn strafestats on." : "disabled.");
	}
	
	return Plugin_Handled;
}

public Action Command_Distbugversion(int client, int args)
{
	ReplyToCommand(client, "Distbugfix version %s", DISTBUG_VERSION);
	return Plugin_Handled;
}

public Action Command_StrafeStats(int client, int args)
{
	if (!IsSettingEnabled(client, FL_SETTINGS_ENABLED))
	{
		return Plugin_Handled;
	}
	
	ToggleSetting(client, FL_SETTINGS_STRAFESTATS);
	
	CPrintToChat(client, "%s Strafe stats have been turned %s.", CHAT_PREFIX, IsSettingEnabled(client, FL_SETTINGS_STRAFESTATS) ? "on" : "off");
	return Plugin_Handled;
}