module image.math;

import std.algorithm;
import std.math;
import std.range;

///	Cast with clipping instead of overflow
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

double l2Norm(R)(R r)
	if (isInputRange!R && is (ElementType!R : double))
{
	return sqrt(r.map!(x => cast(double)(x * x)).sum);
}

unittest
{
	assert(l2Norm([1, 1, 3, 5]) == 6.0, "Array of ints");
	assert(l2Norm([1.0, 1.0, 3.0, 5.0]) == 6.0, "Array of doubles");
	assert(l2Norm(new double[0]) == 0.0, "Empty range");
}