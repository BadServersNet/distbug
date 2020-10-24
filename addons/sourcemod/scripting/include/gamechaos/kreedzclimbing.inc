//
// Useful things for making plugins for Kreedz Climbing
//

#if defined _kreedzclimbing_included
	#endinput
#endif
#define _kreedzclimbing_included

#define MAX_COURSE_SIZE		128		// Reasonable maximum characters a course name can have
#define COURSE_CVAR_COUNT	20		// the amount of Course<int> cvars

// Kreedz Climbing Client Commands:
// These may be executed by a player via the console, with / in chat, or via binds.

// specmode - Cycles spectator mode (F3 by default).
// kz_pause - Pauses the timer.
// flare - Fires a flare.
// gototimer | start - Returns to the last pressed start timer.
// spectate | spec - Enters spectator mode.
// forcespectator - Becomes a spectator no matter what (force respawns a dead player as well).
// stoptimer - Instantly stops the player's timer.
// climb | ct - Respawns at the map spawnpoint.
// InvalidateTimer - Invalidates the player's timer. An invalid timer can't earn rewards for completing the course. InvalidateTimer 1 displays the message, without the 1 it does not.

// Kreedz Climbing Constants

// Timer state (player->m_Local->Timer_Active)
#define TIMER_STATE_INVISIBLE						0
#define TIMER_STATE_ACTIVE							1
#define TIMER_STATE_INACTIVE						2
#define TIMER_STATE_PAUSED							3

// Timer flags (player_manager->m_iTimerFlags[32])
// These are replicated flags for player's timer (most timer data is local to it's own player).
// Note that these flags are mirrors of data local to the player - they are set to the player's 
// state every frame and cannot be changed.

#define TIMER_FLAG_INVALID							(1 << 0)
#define TIMER_FLAG_ACTIVE							(1 << 1) // We need to broadcast this because Timer_State is local only.
#define TIMER_FLAG_PAUSED							(1 << 2) // A paused timer cannot be active and vice versa.

// Environmental Attributes (player->m_iEnvironmentalAttributes)
#define PLAYER_ENV_ATTRIBUTES_BHOP					(1 << 0)
#define PLAYER_ENV_ATTRIBUTES_SURF					(1 << 1)
#define PLAYER_ENV_ATTRIBUTES_AUTOBHOP				(1 << 2)
#define PLAYER_ENV_ATTRIBUTES_CSGOMOVEMENT			(1 << 3)
#define PLAYER_ENV_ATTRIBUTES_CSGODUCKHULL			(1 << 4)

// Movement restriction flags (player->m_iMovementRestrictions) (new version of Environmental Restrictions below)
#define PLAYER_MOVEMENT_RESTRICTION_NOJUMP			(1 << 0)
#define PLAYER_MOVEMENT_RESTRICTION_NOBHOP			(1 << 1)
#define PLAYER_MOVEMENT_RESTRICTION_NODOUBLEDUCK	(1 << 2)

// OBSOLETE: ONLY IN OLD MAPS: Environmental Restrictions (player->m_iEnvironmentalRestrictions), note not flags, complete integer.
#define PLAYER_ENV_RESTRICTION_NOJUMP				1
#define PLAYER_ENV_RESTRICTION_NOBHOP 				2
#define PLAYER_ENV_RESTRICTION_BOTH 				3

// Cooperative status (player->m_Local.m_multiplayercoursedata.Player1Status, Player2Status etc)
#define COOPERATIVE_STATUS_NONE						0
#define COOPERATIVE_STATUS_WAITING					1
#define COOPERATIVE_STATUS_READY					2
#define COOPERATIVE_STATUS_TIMER_ACTIVE				3
#define COOPERATIVE_STATUS_TIMER_COMPLETE			4
#define COOPERATIVE_STATUS_PLAYER_DISCONNECTED		5 // Player disconnected from server, waiting for them to reconnect.
#define COOPERATIVE_STATUS_TIMER_PAUSED				6

// Kreedz Climbing Button Constants
#define IN_CHECKPOINT	(1 << 25) 
#define IN_TELEPORT		(1 << 26)
#define IN_SPECTATE		(1 << 27)
//#define IN_AVAILABLE		(1 << 28) // Unused
#define IN_HOOK			(1 << 29)

// converts the course id from the obsolete "player_starttimer" event into the course name
stock void CourseidToString(int courseid, char[] course, int size)
{
	char szCourseid[16];
	if (courseid < 1 || courseid > COURSE_CVAR_COUNT)
	{
		return;
	}
	FormatEx(szCourseid, sizeof(szCourseid), "Course%i", courseid);
	FindConVar(szCourseid).GetString(course, size);
}

stock void CurrentMapCourses(ArrayList &array)
{
	if (array == null)
	{
		// 1 for endurance bool
		array = new ArrayList(ByteCountToCells(MAX_COURSE_SIZE) + 1);
	}
	else
	{
		array.Clear();
	}
	
	char szCourse[MAX_COURSE_SIZE];
	
	int ent;
	while((ent = FindEntityByClassname(ent, "func_stoptimer")) != -1) 
	{
		int courseid = GetEntProp(ent, Prop_Data, "CourseID");
		CourseidToString(courseid, szCourse, sizeof(szCourse));
		array.PushString(szCourse);
		
		bool endurance = IsCourseEndurance(szCourse, ent);
		array.Set(array.Length - 1, endurance, ByteCountToCells(MAX_COURSE_SIZE));
	}
	
	int courseStringtableCount;
	int courseNamesIdx = FindStringTable("CourseNames");
	courseStringtableCount = GetStringTableNumStrings(courseNamesIdx);
	
	for (int i; i < courseStringtableCount; i++)
	{
		ReadStringTable(courseNamesIdx, i, szCourse, sizeof(szCourse));
		array.PushString(szCourse);
		
		bool endurance = IsCourseEndurance(szCourse, ent);
		array.Set(array.Length - 1, endurance, ByteCountToCells(MAX_COURSE_SIZE));
	}
}

stock int TimerState(int client)
{
	return GetEntProp(client, Prop_Send, "Timer_Active");
}

stock void SetTimerState(int client, int timerstate)
{
	SetEntProp(client, Prop_Send, "Timer_Active", timerstate);
}

stock int PlayerEnvAttributes(int client)
{
	return GetEntProp(client, Prop_Send, "m_iEnvironmentalAttributes");
}

stock void SetPlayerEnvAttributes(int client, int attributes)
{
	SetEntProp(client, Prop_Send, "m_iEnvironmentalAttributes", attributes);
}

stock int PlayerMovementRestrictions(int client)
{
	return GetEntProp(client, Prop_Send, "m_iMovementRestrictions");
}

stock void SetPlayerMovementRestrictions(int client, int restrictions)
{
	SetEntProp(client, Prop_Send, "m_iMovementRestrictions", restrictions);
}

stock void SetActiveCourse(int client, int course)
{
	int ent = FindEntityByClassname(0, "player_manager");
	int courseOffset = FindSendPropInfo("CPlayerResource", "m_iActiveCourse");
	SetEntData(ent, courseOffset + (client * 4), course);
}

stock int TimerFlags(int client)
{
	int ent = FindEntityByClassname(0, "player_manager");
	int courseOffset = FindSendPropInfo("CPlayerResource", "m_iTimerFlags");
	return GetEntData(ent, courseOffset + (client * 4));
}

stock bool InvalidateTimer(int client)
{
	if (~TimerFlags(client) & TIMER_FLAG_INVALID)
	{
		FakeClientCommand(client, "InvalidateTimer 1");
		return true;
	}
	
	return false;
}

stock bool IsCourseEndurance(char[] szCourse, int ent = -1)
{
	if (ent != -1)
	{
		if (IsValidEntity(ent))
		{
			return !!(GetEntProp(ent, Prop_Data, "m_bEnduranceCourse"));
		}
	}
	
	while ((ent = FindEntityByClassname(ent, "point_climbtimer")) != -1)
	{
		if (IsValidEntity(ent))
		{
			char szBuffer[MAX_COURSE_SIZE];
			GetEntPropString(ent, Prop_Data, "m_strCourseName", szBuffer, sizeof(szBuffer));
			PrintToChatAll("course %s", szBuffer);
			
			if (StrEqual(szBuffer, szCourse))
			{
				return !!(GetEntProp(ent, Prop_Data, "m_bEnduranceCourse"));
			}
		}
	}
	
	while ((ent = FindEntityByClassname(ent, "func_stoptimer")) != -1)
	{
		if (IsValidEntity(ent))
		{
			char szBuffer[MAX_COURSE_SIZE];
			int courseid = GetEntProp(ent, Prop_Data, "CourseID");
			CourseidToString(courseid, szBuffer, sizeof(szBuffer));
			
			if (StrEqual(szBuffer, szCourse))
			{
				return !!(GetEntProp(ent, Prop_Data, "m_bEnduranceCourse"));
			}
		}
	}
	
	return false;
}