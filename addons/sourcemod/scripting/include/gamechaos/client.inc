
#if defined _gamechaos_stocks_client_included
	#endinput
#endif
#define _gamechaos_stocks_client_included

#define GC_CLIENT_VERSION 0x01_00_00
#define GC_CLIENT_VERSION_STRING "1.0.0"

/**
 * Credit: Don't remember.
 * Removes a player's weapon from the specified slot.
 *
 * @param client			Client index.
 * @param slot				Weapon slot.
 * @return 					True if removed, false otherwise.
 */
stock bool GCRemoveWeaponBySlot(int client, int slot)
{
	int entity = GetPlayerWeaponSlot(client, slot);
	if (IsValidEdict(entity))
	{
		RemovePlayerItem(client, entity);
		AcceptEntityInput(entity, "kill");
		return true;
	}
	return false;
}

/**
 * Checks if a client is valid and not the server and optionally, whether he's alive.
 *
 * @param client			Client index.
 * @param alive				Whether to check alive.
 * @return 					True if valid, false otherwise.
 */
stock bool GCIsValidClient(int client, bool alive = false)
{
	return (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client) && (!alive || IsPlayerAlive(client)));
}



/**
 * Gets the value of m_flForwardMove.
 *
 * @param client			Client index.
 * @return					Value of m_flForwardMove.
 */
stock float GCGetClientForwardMove(int client)
{
	return GetEntPropFloat(client, Prop_Data, "m_flForwardMove");
}

/**
 * Gets the value of m_flSideMove.
 *
 * @param client			Client index.
 * @return					Value of m_flSideMove.
 */
stock float GCGetClientSideMove(int client)
{
	return GetEntPropFloat(client, Prop_Data, "m_flSideMove");
}

/**
 * Gets the client's abs origin.
 *
 * @param client			Client index.
 * @return result			Player's origin.
 */
stock float[] GCGetClientAbsOriginRet(int client)
{
	float result[3]
	GetClientAbsOrigin(client, result);
	return result;
}

/**
 * Copies the client's velocity to a vector.
 *
 * @param client			Client index.
 * @param result			Resultant vector.
 */
stock void GCGetClientVelocity(int client, float result[3])
{
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", result);
}

/**
 * Gets the client's velocity (m_vecVelocity).
 *
 * @param client			Client index.
 * @return result			m_vecVelocity.
 */
stock float[] GCGetClientVelocityRet(int client)
{
	float result[3]
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", result);
	return result
}

/**
 * Copies the client's basevelocity to a vector.
 *
 * @param client			Client index.
 * @param result			Resultant vector.
 */
stock void GCGetClientBaseVelocity(int client, float result[3])
{
	GetEntPropVector(client, Prop_Data, "m_vecBaseVelocity", result);
}

/**
 * Gets the client's basevelocity (m_vecBaseVelocity).
 *
 * @param client			Client index.
 * @return result			m_vecBaseVelocity.
 */
stock float[] GCGetClientBaseVelocityRet(int client)
{
	float result[3];
	GetEntPropVector(client, Prop_Data, "m_vecBaseVelocity", result);
	return result;
}


/**
 * Gets the client's "m_flDuckSpeed" value.
 *
 * @param client			Client index.
 * @return					"m_flDuckSpeed".
 */
stock float GCGetClientDuckSpeed(int client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flDuckSpeed");
}

/**
 * Gets the client's "m_flDuckAmount" value.
 *
 * @param client			Client index.
 * @return					"m_flDuckAmount".
 */
stock float GCGetClientDuckAmount(int client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flDuckAmount");
}

/**
 * Gets the client's "m_bDucking" value.
 *
 * @param client			Client index.
 * @return					"m_bDucking".
 */
stock int GCGetClientDucking(int client)
{
	return GetEntProp(client, Prop_Data, "m_bDucking");
}

/**
 * Gets the client's "m_flMaxspeed" value.
 *
 * @param client			Client index.
 * @return					"m_flMaxspeed".
 */
stock float GCGetClientMaxspeed(int client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
}

/**
 * Gets the client's "m_afButtonPressed" value.
 *
 * @param client			Client index.
 * @return					"m_afButtonPressed".
 */
stock int GCGetClientButtonPressed(int client)
{
	return GetEntProp(client, Prop_Data, "m_afButtonPressed");
}

/**
 * Gets the client's "m_afButtonReleased" value.
 *
 * @param client			Client index.
 * @return					"m_afButtonReleased".
 */
stock int GCGetClientButtonReleased(int client)
{
	return GetEntProp(client, Prop_Data, "m_afButtonReleased");
}

/**
 * Gets the client's "m_afButtonLast" value.
 *
 * @param client			Client index.
 * @return					"m_afButtonLast".
 */
stock int GCGetClientButtonLast(int client)
{
	return GetEntProp(client, Prop_Data, "m_afButtonLast");
}

/**
 * Gets the client's "m_afButtonForced" value.
 *
 * @param client			Client index.
 * @return					"m_afButtonForced".
 */
stock int GCGetClientForcedButtons(int client)
{
	return GetEntProp(client, Prop_Data, "m_afButtonForced");
}

/**
 * Gets the client's "m_flStamina" value.
 *
 * @param client			Client index.
 * @return					"m_flStamina".
 */
stock float GCGetClientStamina(int client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flStamina");
}



/**
 * Sets the client's origin.
 *
 * @param client			Client index.
 * @param origin			New origin.
 */
stock void GCSetClientAbsOrigin(int client, const float origin[3])
{
	SetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", origin);
}

/**
 * Sets the client's velocity.
 *
 * @param client			Client index.
 * @param velocity			New velocity.
 */
stock void GCSetClientVelocity(int client, const float velocity[3])
{
	SetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
}

/**
 * Sets the client's "m_vecAbsVelocity".
 *
 * @param client			Client index.
 * @param velocity			New "m_vecAbsVelocity".
 */
stock void GCSetClientAbsVelocity(int client, const float velocity[3])
{
	SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);
}

/**
 * Sets the client's eye angles.
 * Ang has to be a 2 member array or more
 *
 * @param client			Client index.
 * @param ang				New eyeangles.
 */
stock void GCSetClientEyeAngles(int client, const float[] ang)
{
	SetEntPropFloat(client, Prop_Send, "m_angEyeAngles[0]", ang[0]);
	SetEntPropFloat(client, Prop_Send, "m_angEyeAngles[1]", ang[1]);
}


/**
 * Sets the client's "m_flDuckSpeed".
 *
 * @param client			Client index.
 * @param value			New "m_flDuckSpeed".
 */
stock void GCSetClientDuckSpeed(int client, float value)
{
	SetEntPropFloat(client, Prop_Send, "m_flDuckSpeed", value);
}

stock void GCSetClientDuckAmount(int client, float value)
{
	SetEntPropFloat(client, Prop_Send, "m_flDuckAmount", value);
}

stock void GCSetClientForcedButtons(int client, int buttons)
{
	SetEntProp(client, Prop_Data, "m_afButtonForced", buttons);
}

stock void GCSetClientStamina(int client, float stamina)
{
	SetEntPropFloat(client, Prop_Send, "m_flStamina", stamina)
}