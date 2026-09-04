
#if defined _gamechaos_stocks_vectors_included
	#endinput
#endif
#define _gamechaos_stocks_vectors_included

#define GC_VECTORS_VERSION 0x01_00_01
#define GC_VECTORS_VERSION_STRING "1.0.1"

/**
 * Calculates the horizontal (x, y) length of a vector.
 *
 * @param vec				Vector.
 * @return 					Vector length (magnitude).
 */
stock float GCGetVectorLength2D(const float vec[3])
{
	float tempVec[3];
	tempVec = vec;
	tempVec[2] = 0.0;
	
	return GetVectorLength(tempVec);
}

/**
 * Calculates the horizontal (x, y) distance between 2 vectors.
 *
 * @param x					Vector 1.
 * @param y					Vector 2.
 * @param tolerance			How close the floats have to be to return true.
 * @return 					True on success, false otherwise.
 */
stock float GCGetVectorDistance2D(const float x[3], const float y[3])
{
	float x2[3];
	float y2[3];
	
	x2 = x;
	y2 = y;
	
	x2[2] = 0.0;
	y2[2] = 0.0;
	
	return GetVectorDistance(x2, y2);
}

/**
 * Checks if 2 vectors are exactly equal.
 *
 * @param a					Vector 1.
 * @param b					Vector 2.
 * @return 					True on success, false otherwise.
 */
stock bool GCVectorsEqual(const float a[3], const float b[3])
{
	bool result = true;
	for (int i = 0; i < 3; i++)
	{
		if (a[i] != b[i])
		{
			result = false;
			break;
		}
	}
	return result;
}