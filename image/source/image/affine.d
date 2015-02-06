module image.affine;

import std.algorithm;
import ae.utils.graphics.image;

import image.math;

enum ScalingMethod
{
	Nearest, Bilinear
}

/// Returns scaled copy of input
auto scale(V)(V view, int w, int h, ScalingMethod method = ScalingMethod.Nearest)
	if (isView!V)
{
	final switch(method)
	{
		case ScalingMethod.Nearest:
			return nearestNeighbor(img, w, h);
		case ScalingMethod.Bilinear:
			return scaleBilinear(img, scaleFactor);
	}
}

auto scaleBilinear(V)(V view, int w, int h)
	if (isView!V)
{
	auto scaled = ViewImage!V(w, h);

	auto hStep = view.w / cast(double)(w);
	auto vStep = view.h / cast(double)(h);

	auto xIn = 0.0;
	auto yIn = 0.0;

	for (uint yOut = 0; yOut < h; ++yOut, yIn += vStep, xIn = 0.0)
	{	
		auto inRow = min(view.h - 1, cast(uint)(yIn));
		auto nextRow = min(view.h - 1, inRow + 1);
		auto dy = yIn - inRow;

		for (uint xOut = 0; xOut < w; ++xOut, xIn += hStep)
		{
			auto inCol = min(view.w -1, cast(uint)(xIn));
			auto nextCol = min(view.w - 1, inCol + 1);
			auto dx = xIn - inCol;

			auto pix = ViewColor!V.init;

			/// TODO: same issue as image.filter.hFilter
			foreach(i, ref p; pix.tupleof)
			{
				auto interTop = (1.0 - dx) * view[inCol, inRow].tupleof[i] + dx * view[nextCol, inRow].tupleof[i];
				auto interBot = (1.0 - dx) * view[inCol, nextRow].tupleof[i] + dx * view[nextCol, nextRow].tupleof[i];
				auto inter 	  = (1.0 - dy) * interTop + dy * interBot;

				// TODO: Using roundTo here makes this function 35x slower
				// 		 Write a fast rounding function as that's what we actually want
				p = clipTo!(typeof(p))(inter);
			}

			scaled[xOut, yOut] = pix;
		}
	}
	
	return scaled;
}

/// Translates the image by (tx, ty) (x increases rightwards, 
/// y increases downwards, as usual)
/// TODO: 
/// 	Trying to call this results in:
/// 
/// 	ae-graphics-0.0.3/ae/utils/graphics/view.d(483): 
/// 	Error: this.bg.opIndex(x, y) is not an lvalue
//auto translate(V)(V view, int tx, int ty)
//{
//	auto lPad = tx > 0 ? tx : 0;
//	auto rPad = tx > 0 ? 0 : -tx;
//	auto tPad = ty > 0 ? ty : 0;
//	auto bPad = ty > 0 ? 0 : -ty;
//
//	auto val = ViewColor!V.init;
//	return view
//		.border(lPad, rPad, tPad, bPad, val)
//		.crop(rPad, bPad, rPad + view.width, bPad + view.height);
//}