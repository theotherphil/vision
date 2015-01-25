module image.contrast;

import std.algorithm;
import ae.utils.graphics.image;

///**
//Applies fun to a copy of img and returns result
//*/
//Image!Pix copy_and_then(alias fun, Pix, T...)(const Image!Pix img, T args)
//{
//	auto copy = img.dup;
//	fun(copy, args);
//	return copy; 
//}

/**
	Copies view into a newly allocated image and updates that in place
*/
Image!(ViewColor!V) copyAndThen(alias fun, V, T...)(V view, T args)
	if (isView!V)
{
	auto mut = Image!(ViewColor!V)(view.w, view.h);
	view.copy(mut);
	fun(mut, args);
	return mut;
}

//@RegressionTested
//auto equalise_histogram(Image!ubyte img)
//{
//	return copy_and_then!equalise_histogram_mut(img);
//}
//
//uint[256] histogram(Image!ubyte img)
//{
//	uint[256] hist;
//	hist[] = 0;
//	
//	foreach (pix; img.sample_range)
//		++hist[pix];
//	
//	for (uint i = 1; i < 256; ++i)
//		hist[i] += hist[i - 1];
//	
//	return hist;
//}
//
//void equalise_histogram_mut(Image!ubyte img)
//{
//	auto hist    = histogram(img);
//	double total = hist[255];
//	
//	foreach (ref pix; img.sample_range)
//	{
//		auto v = min(255.0, 255.0 * hist[pix] / total);
//		pix = cast(ubyte)v;
//	}
//}

/**
	Linearly stretches pixel intensities so that the low_percent quantile of img goes to 0
	and high_percent quantile goes to 255.
*/
void stretch_contrast_mut(Image!ubyte img, double low_percent = 5.0, double high_percent = 5.0)
{
	// something something
}

void match_histogram_mut(Image!ubyte img, Image!ubyte target)
{
	// know img -> flat, target -> flat. Apply first, invert second
}

// adaptive local histogram equalisation/matching