module image.util;

import std.array;
import std.algorithm;

import ae.utils.graphics.color;
import ae.utils.graphics.image;

import image.math;
import image.viewrange;

enum is8BitGreyscale(V) = is (ViewColor!V == L8);

static assert(is8BitGreyscale!(Image!L8));

/// What to do with pixels that lie outside an image boundary
enum Padding
{
	Continuity, /// Treat the outermost pixel as repeating forever
	Init 		/// Treat all pixels outside the image as having the
				/// default value for their colour type
}

L8 toL8(T)(T x)
{
	return L8(clipTo!ubyte(x));
}

L16 toL16(T)(T x)
{
	return L16(clipTo!ushort(x));
}

unittest
{
	assert(500.0.toL8 == L8(255));
	assert((-1.0).toL8 == L8(0));
}

auto toL8(int[] xs, int w, int h)
{
	return to!L8(xs, w, h);
}

auto toL16(int[] xs, int w, int h)
{
	return to!L16(xs, w, h);
}

private auto to(C)(int[] xs, int w, int h)
{
	auto img = Image!C(w, h);
	for (auto y = 0; y < h; ++y)
	{
		for (auto x = 0; x < w; ++x)
		{
			static if (is (C == L8))
			{
				img[x, y] = xs[y * w + x].toL8;
			}
			else
			{
				img[x, y] = xs[y * w + x].toL16;
			}
		}
			
	}
	return img;
}

///	Copies view into a newly allocated image and updates that in place
Image!(ViewColor!V) copyAndThen(alias fun, V, T...)(V view, T args)
	if (isView!V)
{
	auto mut = ViewImage!V(view.w, view.h);
	view.copy(mut);
	fun(mut, args);
	return mut;
}

// TODO: mixin to generate copying version from mutating version

version(unittest)
{
	import std.math;

	bool equalWithin(double x, double y, double eps)
	{
		return abs(x - y) < eps;
	}
}

/// Creates a new image by padding view with margins of the given sizes
ViewImage!V pad(V)(V view, uint margin, Padding cond = Padding.Init)
{
	return pad(view, margin, margin, margin, margin, cond);
}

/// ditto
ViewImage!V pad(V)(V view, uint left, uint top, uint right, uint bottom, 
	Padding cond = Padding.Init)
{
	auto width  = view.w + left + right;
	auto height = view.h + top + bottom;

	auto padded = ViewImage!V(width, height);
	
	for (uint y = 0; y < view.h; ++y)
		for (uint x = 0; x < view.w; ++x)
			padded[x + left, y + top] = view[x, y];
	
	if (cond == Padding.Continuity)
	{
		// Pad top centre
		for (uint x = 0; x < view.w; ++x)
		{
			auto pix = view[x, 0];
			
			for (uint y = 0; y < top; ++y)
				padded[x + left, y] = pix;
		}
		// Pad bottom centre
		for (uint x = 0; x < view.w; ++x)
		{
			auto pix = view[x, view.h - 1];
			
			for (uint y = view.h + top; y < padded.h; ++y)
				padded[x + left, y] = pix;
		}
		// Pad right centre
		for (uint y = 0; y < view.h; ++y)
		{
			auto pix = view[0, y];
			
			for (uint x = 0; x < left; ++x)
				padded[x, y + top] = pix;
		}
		// Pad left centre
		for (uint y = 0; y < view.h; ++y)
		{
			auto pix = view[view.w - 1, y];
			
			for (uint x = view.w + left; x < padded.w; ++x)
				padded[x, y + top] = pix;
		}
		// Pad corners
		auto topLeft  = view[0,		  0	        ];
		auto topRight = view[view.w - 1, 0         ];
		auto botLeft  = view[0,		  view.h - 1];
		auto botRight = view[view.w - 1, view.h - 1];
		
		for (uint y = 0; y < top; ++y)
		{
			for (uint x = 0; x < left; ++x)
				padded[x, y] = topLeft;
			for (uint x = view.w + left; x < padded.w; ++x)
				padded[x, y] = topRight;
		}

		for (uint y = view.h + top; y < padded.h; ++y)
		{
			for (uint x = 0; x < left; ++x)
				padded[x, y] = botLeft;
			for (uint x = view.w + left; x < padded.w; ++x)
				padded[x, y] = botRight;
		}
	}
	
	return padded;
}

unittest
{
	auto img =
		[1, 2, 3,
	 	 4, 5, 6,
		 7, 8, 9].toL8(3, 3);

	auto p = img.pad(1, Padding.Continuity);

	auto expected = 
		[1, 1, 2, 3, 3,
		 1, 1, 2, 3, 3,
		 4, 4, 5, 6, 6,
		 7, 7, 8, 9, 9,
		 7, 7, 8, 9, 9].toL8(5, 5);

	assert(p.pixelsEqual(expected));
}