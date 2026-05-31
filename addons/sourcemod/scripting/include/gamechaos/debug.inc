
// gamechaos's debug stocks
// useful stocks for debugging

#if defined _gamechaos_debug_included
	#endinput
#endif
#define _gamechaos_debug_included

#define GC_DEBUG_VERSION 0x1_00_00
#define GC_DEBUG_VERSION_STRING "1.0.0"

#if defined GC_DEBUG
	#define GC_ASSERT(%1) if (!(%1))SetFailState("Assertion failed: \""...#%1..."\"")
	#define GC_DEBUGPRINT(%1) PrintToChatAll(%1)
#else
	#define GC_ASSERT(%1)%2;
	#define GC_DEBUGPRINT(%1)%2;
#endif
