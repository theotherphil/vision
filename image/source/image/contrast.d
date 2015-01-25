module image.contrast;

import std.algorithm;
import std.array;
import std.conv;

import ae.utils.graphics.image;
import ae.utils.graphics.color;

import image.viewrange;

///	Copies view into a newly allocated image and updates that in place
Image!(ViewColor!V) copyAndThen(alias fun, V, T...)(V view, T args)
	if (isView!V)
{
	auto mut = ViewImage!V(view.w, view.h);
	view.copy(mut);
	fun(mut, args);
	return mut;
}

int[256] cumulativeHistogram(V)(V view)
	if (isView!V && is (ViewColor!V == L8))
{
	int[256] hist;
	hist[] = 0;

	foreach (pix; view.source)
		++hist[pix.l];

	for (uint i = 1; i < 256; ++i)
		hist[i] += hist[i - 1];

	return hist;
}

unittest
{
	L8 toL8(int x){ return L8(cast(ubyte)x); }
	L8[] row = [1, 2, 3, 2, 1].map!toL8.array;

	auto img = procedural!((x, y) => row[x])(5, 1);
	auto hist = img.cumulativeHistogram;

	assert(hist[0 .. 4] == [0, 2, 4, 5]);
	assert(hist[4 .. $].all!(x => x == 5));
}

void equaliseHistogramMut(V)(V view)
	if (isWritableView!V && is (ViewColor!V == L8))
{
	auto hist    = cumulativeHistogram(view);
	double total = hist[255];

	foreach (ref pix; view.source)
	{
		auto v = min(255.0, 255.0 * hist[pix.l] / total);
		pix = L8(cast(ubyte)v);
	}
}

auto equaliseHistogram(V)(V view)
	if (isView!V && is (ViewColor!V == L8))
{
	return copyAndThen!equaliseHistogramMut(view);
}

// TODO: constrast stretch, histogram match, adapative local histogram equalisation