
#if defined _gamechaos_stocks_tempents_included
	#endinput
#endif
#define _gamechaos_stocks_tempents_included

// improved api of some tempents

#define GC_TEMPENTS_VERSION 0x01_00_00
#define GC_TEMPENTS_VERSION_STRING "1.0.0"

#include <sdktools_tempents>

/**
 * Sets up a point to point beam effect.
 *
 * @param start         Start position of the beam.
 * @param end           End position of the beam.
 * @param modelIndex    Precached model index.
 * @param life          Time duration of the beam.
 * @param width         Initial beam width.
 * @param endWidth      Final beam width.
 * @param colour        Color array (r, g, b, a).
 * @param haloIndex     Precached model index.
 * @param amplitude     Beam amplitude.
 * @param speed         Speed of the beam.
 * @param fadeLength    Beam fade time duration.
 * @param frameRate     Beam frame rate.
 * @param startFrame    Initial frame to render.
 */
stock void GCTE_SetupBeamPoints(const float start[3],
								const float end[3],
								int modelIndex,
								float life = 2.0,
								float width = 2.0,
								float endWidth = 2.0,
								const int colour[4] = {255, 255, 255, 255},
								int haloIndex = 0,
								float amplitude = 0.0,
								int speed = 0,
								int fadeLength = 0,
								int frameRate = 0,
								int startFrame = 0)
{
	TE_Start("BeamPoints");
	TE_WriteVector("m_vecStartPoint", start);
	TE_WriteVector("m_vecEndPoint", end);
	TE_WriteNum("m_nModelIndex", modelIndex);
	TE_WriteNum("m_nHaloIndex", haloIndex);
	TE_WriteNum("m_nStartFrame", startFrame);
	TE_WriteNum("m_nFrameRate", frameRate);
	TE_WriteFloat("m_fLife", life);
	TE_WriteFloat("m_fWidth", width);
	TE_WriteFloat("m_fEndWidth", endWidth);
	TE_WriteFloat("m_fAmplitude", amplitude);
	TE_WriteNum("r", colour[0]);
	TE_WriteNum("g", colour[1]);
	TE_WriteNum("b", colour[2]);
	TE_WriteNum("a", colour[3]);
	TE_WriteNum("m_nSpeed", speed);
	TE_WriteNum("m_nFadeLength", fadeLength);
}