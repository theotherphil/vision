module image.util;

import std.array;
import std.algorithm;

import ae.utils.graphics.color;
import ae.utils.graphics.view;

L8 toL8(int x)
{ 
	return L8(cast(ubyte)x); 
}

auto toL8(int[] xs, int w, int h)
{
	return procedural!((x, y) => xs.map!toL8[y * w + x])(w, h);
}


