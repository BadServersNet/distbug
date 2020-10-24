
#if defined _gamechaos_isvalidclient_client_included
	#endinput
#endif
#define _gamechaos_isvalidclient_client_included

/**
 * Checks if a client is valid.
 *
 * @param client			Client index.
 * @return 					True if valid, false otherwise.
 */
stock bool IsValidClient(int client)
{
	return (client >= 0 && client <= MaxClients && IsValidEntity(client) && IsClientConnected(client) && IsClientInGame(client));
}