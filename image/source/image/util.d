module image.util;

import std.array;
import std.algorithm;

import ae.utils.graphics.color;
import ae.utils.graphics.image;

enum is8BitGreyscale(V) = is (ViewColor!V == L8);

static assert(is8BitGreyscale!(Image!L8));

L8 toL8(int x)
{ 
	return L8(cast(ubyte)x); 
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