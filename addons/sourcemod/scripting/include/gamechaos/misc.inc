
#if defined _gamechaos_stocks_misc_included
	#endinput
#endif
#define _gamechaos_stocks_misc_included

#define GC_MISC_VERSION 0x01_00_00
#define GC_MISC_VERSION_STRING "1.0.0"

/**
 * Check if player is overlapping their MOVERIGHT and MOVELEFT buttons.
 *
 * @param x					Buttons;
 * @return 					True if overlapping, false otherwise.
 */
stock bool GCIsOverlapping(int buttons)
{
	return buttons & IN_MOVERIGHT && buttons & IN_MOVELEFT
}

/**
 * Checks if player gained speed.
 *
 * @param speed				Current player speed.
 * @param lastspeed			Player speed from previous tick.
 * @return 					True if player gained speed, false otherwise.
 */
stock bool GCIsStrafeSynced(float speed, float lastspeed)
{
	return speed > lastspeed;
}

/**
 * Checks if the player is not holding down their MOVERIGHT and MOVELEFT buttons.
 *
 * @param x					Buttons.
 * @return 					True if they're not holding either, false otherwise.
 */
stock bool GCIsDeadAirtime(int buttons)
{
	return !(buttons & IN_MOVERIGHT) && !(buttons & IN_MOVELEFT);
}

/** 
* Source: https://forums.alliedmods.net/showthread.php?p=2535972
* Runs a single line of vscript code. 
* NOTE: Dont use the "script" console command, it startes a new instance and leaks memory. Use this instead! 
* 
* @param code				The code to run. 
* @noreturn 
*/ 
stock void GCRunScriptCode(const char[] code, any ...) 
{ 
	static int scriptLogic = INVALID_ENT_REFERENCE; 
	
	if (scriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(scriptLogic))
	{
		scriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script")); 
		if (scriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(scriptLogic))
		{
			SetFailState("Could not create a 'logic_script' entity."); 
		}
		
		DispatchSpawn(scriptLogic); 
	} 
	
	char buffer[512]; 
	VFormat(buffer, sizeof(buffer), code, 2); 
	
	SetVariantString(buffer); 
	AcceptEntityInput(scriptLogic, "RunScriptCode"); 
}

stock void GCTE_SendBeamBox(int client,
						  const float origin[3],
						  const float mins[3],
						  const float maxs[3],
						  int ModelIndex,
						  int HaloIndex = 0,
						  float Life = 3.0,
						  float Width = 2.0,
						  const int Colour[4] =  { 255, 255, 255, 255 },
						  float EndWidth = 2.0,
						  int StartFrame = 0,
						  int FrameRate = 0,
						  int FadeLength = 0,
						  float Amplitude = 0.0,
						  int Speed = 0)
{
	// credit to some bhop timer by shavit? thanks
	int pairs[8][3] =  { { 0, 0, 0 }, { 1, 0, 0 }, { 1, 1, 0 }, { 0, 1, 0 }, { 0, 0, 1 }, { 1, 0, 1 }, { 1, 1, 1 }, { 0, 1, 1 } };
	int edges[12][2] =  { { 0, 1 }, { 0, 3 }, { 0, 4 }, { 2, 1 }, { 2, 3 }, { 2, 6 }, { 5, 4 }, { 5, 6 }, { 5, 1 }, { 7, 4 }, { 7, 6 }, { 7, 3 } };
	
	float corners[8][3];
	float corner[2][3];
	
	AddVectors(origin, mins, corner[0]);
	AddVectors(origin, maxs, corner[1]);
	
	for (int i = 0; i < 8; i++)
	{
		corners[i][0] = corner[pairs[i][0]][0];
		corners[i][1] = corner[pairs[i][1]][1];
		corners[i][2] = corner[pairs[i][2]][2];
	}
	
	for (int i = 0; i < 12; i++)
	{
		TE_SetupBeamPoints(corners[edges[i][0]],
						   corners[edges[i][1]],
						   ModelIndex,
						   HaloIndex,
						   StartFrame,
						   FrameRate,
						   Life,
						   Width,
						   EndWidth,
						   FadeLength,
						   Amplitude,
						   Colour,
						   Speed);
		TE_SendToClient(client);
	}
}

stock void GCTE_SendBeamCross(int client,
							const float origin[3],
							int ModelIndex,
							int HaloIndex = 0,
							float Life = 3.0,
							float Width = 2.0,
							const int Colour[4]  = { 255, 255, 255, 255 },
							float EndWidth = 2.0,
							int StartFrame = 0,
							int FrameRate = 0,
							int FadeLength = 0,
							float Amplitude = 0.0,
							int Speed = 0)
{
	float points[4][3];
	
	for (int i; i < 4; i++)
	{
		points[i][2] = origin[2];
	}
	
	// -x; -y
	points[0][0] = origin[0] - 8.0;
	points[0][1] = origin[1] - 8.0;
	
	// +x; -y
	points[1][0] = origin[0] + 8.0;
	points[1][1] = origin[1] - 8.0;
	
	// +x; +y
	points[2][0] = origin[0] + 8.0;
	points[2][1] = origin[1] + 8.0;
	
	// -x; +y
	points[3][0] = origin[0] - 8.0;
	points[3][1] = origin[1] + 8.0;
	
	//draw cross
	for (int corner; corner < 4; corner++)
	{
		TE_SetupBeamPoints(origin, points[corner], ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Colour, Speed);
		TE_SendToClient(client);
	}
}

stock void GCTE_SendBeamRectangle(int client,
						  const float origin[3],
						  const float mins[3],
						  const float maxs[3],
						  int modelIndex,
						  int haloIndex = 0,
						  float life = 3.0,
						  float width = 2.0,
						  const int colour[4]  = { 255, 255, 255, 255 },
						  float endWidth = 2.0,
						  int startFrame = 0,
						  int frameRate = 0,
						  int fadeLength = 0,
						  float amplitude = 0.0,
						  int speed = 0)
{
	float vertices[4][3];
	GCRectangleVerticesFromPoint(vertices, origin, mins, maxs);
	
	// send the square
	for (int i; i < 4; i++)
	{
		int j = (i == 3) ? (0) : (i + 1);
		TE_SetupBeamPoints(vertices[i],
						   vertices[j],
						   modelIndex,
						   haloIndex,
						   startFrame,
						   frameRate,
						   life,
						   width,
						   endWidth,
						   fadeLength,
						   amplitude,
						   colour,
						   speed);
		TE_SendToClient(client);
	}
}

/**
 * Calculates vertices for a rectangle from a point, mins and maxs.
 *
 * @param result			Vertex array result.
 * @param origin			Origin to offset mins and maxs by.
 * @param mins				Minimum size of the rectangle.
 * @param maxs				Maximum size of the rectangle.
 * @return 					True if overlapping, false otherwise.
 */
stock void GCRectangleVerticesFromPoint(float result[4][3], const float origin[3], const float mins[3], const float maxs[3])
{
	// Vertices are set clockwise starting from top left (-x; -y)
	
	// -x; -y
	result[0][0] = origin[0] + mins[0];
	result[0][1] = origin[1] + mins[1];
	
	// +x; -y
	result[1][0] = origin[0] + maxs[0];
	result[1][1] = origin[1] + mins[1];
	
	// +x; +y
	result[2][0] = origin[0] + maxs[0];
	result[2][1] = origin[1] + maxs[1];
	
	// -x; +y
	result[3][0] = origin[0] + mins[0];
	result[3][1] = origin[1] + maxs[1];
	
	// z is the same for every vertex
	for (int vertex; vertex < 4; vertex++)
	{
		result[vertex][2] = origin[2];
	}
}