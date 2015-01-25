module image.math;

import std.algorithm;

/**
	Cast with clipping instead of overflow
*/
To clipTo(To, From)(From x)
{
	return cast(To)(max(To.min, min(To.max, x)));
}

unittest
{
	assert(clipTo!int(25) == 25, "25 :: int -> 25 :: int");
	assert(clipTo!uint(25) == 25, "25 :: int -> 25 :: uint");
	assert(clipTo!uint(-25) == 0, "-25 :: int -> 0 :: uint");
	assert(clipTo!ubyte(500) == 255, "500 :: int -> 255 :: ubyte");
}