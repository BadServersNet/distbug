
// gamechaos's debug stocks
// useful stocks for debuggin

#if defined _gamechaos_debug_included
	#endinput
#endif
#define _gamechaos_debug_included

stock void PrintDebugChat(int client, char[] szFormat, any ...)
{
	char formattedString[256];
	VFormat(formattedString, sizeof(formattedString), szFormat, 3);
	PrintToChat(client, formattedString);
}