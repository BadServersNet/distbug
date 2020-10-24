
#if defined _gamechaos_stocks_vectors_included
	#endinput
#endif
#define _gamechaos_stocks_vectors_included

/**
 * Calculates the horizontal length of a vector.
 *
 * @param vec				Vector.
 * @return 					Vector length (magnitude).
 */
stock float GetVectorHorLength(const float vec[3])
{
	float tempVec[3];
	tempVec = vec;
	tempVec[2] = 0.0;
	
	return GetVectorLength(tempVec);
}

/**
 * Calculates the horizontal distance between 2 vectors.
 *
 * @param x					Vector 1.
 * @param y					Vector 2.
 * @param tolerance			How close the floats have to be to return true.
 * @return 					True on success, false otherwise.
 */
stock float GetVectorHorDistance(const float x[3], const float y[3])
{
	float x2[3];
	float y2[3];
	
	CopyVector(x, x2);
	CopyVector(y, y2);
	
	x2[2] = 0.0;
	y2[2] = 0.0;
	
	return GetVectorDistance(x2, y2);
}

/**
 * Copies a vector to another vector.
 *
 * @param source			Source vector.
 * @param dest				Destination vector.
 */
stock void CopyVector(const float source[3], float dest[3])
{
	dest[0] = source[0];
	dest[1] = source[1];
	dest[2] = source[2];
}