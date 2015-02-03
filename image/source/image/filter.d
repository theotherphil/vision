module image.filter;

import std.math;

import image.math;
import ae.utils.graphics.image;
import ae.utils.graphics.color;
 
/// What to do when the kernel exceeds an image boundary.
enum Padding
{
	Continuity, /// Treat the outermost pixel as repeating forever
	Init 		/// Treat all pixels outside the image as having the
				/// default value for their colour type
}

///	Returns: Horizontal correlations between input view and 1d kernel
auto horizontalFilter(V)(V view, double[] kernel, Padding padding = Padding.Continuity)
	if (isView!V)
{
	alias Pix = ViewColor!V;
	
	auto k = kernel.length;
	auto blurred = view.copy();
	
	Pix[] buffer;
	buffer.length = view.w + k/2 + k/2;
	
	auto padInit = padding == Padding.Init;

	for (auto y = 0; y < blurred.h; ++y)
	{
		auto leftPad  = padInit ? Pix.init : view[0, y];
		auto rightPad = padInit ? Pix.init : view[view.w - 1, y];
		
		padBuffer(buffer, k/2, leftPad, rightPad);
		
		for (uint x = 0; x < blurred.w; ++x)
			buffer[x + k/2] = view[x, y];
		
		for (auto x = k/2; x < blurred.w + k/2; ++x)
		{
			double[Pix.channels] acc = 0.0;
			for(auto z = 0; z < k; ++z)
			{
				auto pix = buffer[x + z - k/2];

				/// TODO: 
				/// 	Replace loop and double[] with
				/// 	something like:
				/// 
				/// 	alias DPix = ChangeChannelType!(Pix, double);
				/// 	
				/// 	... intermediate calculations on DPix type
				///     ... (note that p :: A + q :: B has type A)
				/// 	
				/// 	casting assign to blurred
				/// 
				/// 	This requires support for floating point
				/// 	channels in ae.graphics.color
				/// 
				/// 	See also scaleBilinear
				foreach (i, f; pix.tupleof)
					acc[i] += f * kernel[z];
			}

			foreach (ref d; acc)
				d /= k;

			auto pix = Pix.init;

			foreach (i, ref f; pix.tupleof)
				f = clipTo!(typeof(f))(acc[i]);

			blurred[cast(int)(x - k/2), y] = pix;
		}
	}

	return blurred;
}

unittest
{
	import image.viewrange;
	import image.util;

	auto c = procedural!((x, y) => L8(cast(ubyte)(x * y + x)))(10, 10);
	auto id = [0.0, 3.0, 0.0];
	assert(c.horizontalFilter(id).pixelsEqual(c));

	auto d = 
		[1, 4, 1,
		 4, 7, 4,
		 1, 4, 1].toL8(3, 3);

	auto box = [1.0, 1.0, 1.0];

	auto expected =
		[2, 2, 2,
		 5, 5, 5,
		 2, 2, 2].toL8(3, 3);

	auto result = d.horizontalFilter(box);
	assert(d.horizontalFilter(box).pixelsEqual(expected));
}

///	Returns: Vertical correlations between input view and 1d kernel
auto verticalFilter(V)(V view, double[] kernel, Padding padding = Padding.Continuity)
	if (isView!V)
{
	return view.flipXY.horizontalFilter(kernel, padding).flipXY;
}

///	Returns: 2d correlation of view with the outer product of the 1d kernels hKernel and vKernel
auto separableFilter(V)(V view, double[] hKernel, double[] vKernel, Padding padding = Padding.Continuity)
	if (isView!V)
{
	return view.horizontalFilter(hKernel, padding).verticalFilter(vKernel, padding);
}

///	Returns: 2d correlation of view with the outer product of kernel with itself 
auto separableFilter(V)(V view, double[] kernel, Padding padding = Padding.Continuity)
	if (isView!V)
{
	return view.separableFilter(kernel, kernel, padding);
}

static double[3] hSobelX = [-1, 0, 1]; /// Horizontal filter to use for horizontal Sobel
static double[3] hSobelY = [1, 2, 1];  /// Vertical filter to use for horizontal Sobel
static double[3] vSobelX = [1, 2, 1];  /// Horizontal filter to use for vertical Sobel
static double[3] vSobelY = [-1, 0, 1]; /// Vertical filter to use for vertical Sobel

/// TODO: for tiny filters do the 2d filter directly (at least for 3x3)
auto horizontalSobel(V)(V view)
	if (isView!V && is (ViewColor!V == L8))
{
	auto sView = view.colorMap!(p => S16(p.l));
	return sView.separableFilter(hSobelX, hSobelY);
}

/// ditto
auto verticalSobel(V)(V view)
	if (isView!V && is (ViewColor!V == L8))
{
	auto sView = view.colorMap!(p => S16(p.l));
	return sView.separableFilter(vSobelX, vSobelY);
}

unittest
{
	import std.algorithm;
	import image.util;
	import image.viewrange;

	auto flat = solid(L8(1), 3, 3);
	assert(flat.horizontalSobel.source.all!(x => x == S16(0)));
	assert(flat.verticalSobel.source.all!(x => x == S16(0)));

	auto grad = procedural!((x, y) => (3*x).toL8)(4, 4);
	auto mid = grad.horizontalSobel.crop(1, 1, 3, 3);
	assert(mid.source.all!(x => x == S16(2)));
}

auto sobel(V)(V view)
	if (isView!V  && is (ViewColor!V == L8))
{
	auto hSobel = horizontalSobel(view);
	auto vSobel = verticalSobel(view);
	
	auto sobel = Image!L8(view.w, view.h);
	
	for (auto y = 0; y < view.h; ++y)
	{
		for (auto x = 0; x < view.w; ++x)
		{
			double h     = hSobel[x, y].l;
			double v     = vSobel[x, y].l;
			double grad  = sqrt(h * h + v * v);
			
			sobel[x, y] = L8(clipTo!ubyte(grad));
		}
	}
	
	return sobel;
}

/// Fills the left margin entries in buffer with leftVal and the right margin entries with rightVal
private void padBuffer(Pix)(Pix[] buffer, size_t margin, Pix leftVal, Pix rightVal)
{
	for (size_t idx = 0; idx < margin; ++idx)
		buffer[idx] = leftVal;
	
	for (size_t idx = buffer.length - margin; idx < buffer.length; ++idx)
		buffer[idx] = rightVal;
}

unittest
{
	auto a = [0, 1, 2, 3, 0];
	padBuffer(a, 1, 4, 5);
	assert(a == [4, 1, 2, 3, 5]);
	padBuffer(a, 2, 8, 9);
	assert(a == [8, 8, 2, 9, 9]);

	auto b = [0, 1, 2, 0];
	padBuffer(b, 1, 4, 5);
	assert(b == [4, 1, 2, 5]);
	padBuffer(b, 2, 8, 9);
	assert(b == [8, 8, 9, 9]);
}