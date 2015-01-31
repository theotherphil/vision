module image.util;

import std.array;
import std.algorithm;

import ae.utils.graphics.color;
import ae.utils.graphics.image;

import image.math;

enum is8BitGreyscale(V) = is (ViewColor!V == L8);

static assert(is8BitGreyscale!(Image!L8));

L8 toL8(T)(T x)
{
	return L8(clipTo!ubyte(x));
}

unittest
{
	assert(500.0.toL8 == L8(255));
	assert((-1.0).toL8 == L8(0));
}

auto toL8(int[] xs, int w, int h)
{
	auto img = Image!L8(w, h);
	for (auto y = 0; y < h; ++y)
		for (auto x = 0; x < w; ++x)
			img[x, y] = xs[y * w + x].toL8;
	return img;
}

version(unittest)
{
	import std.math;

	bool equalWithin(double x, double y, double eps)
	{
		return abs(x - y) < eps;
	}
}