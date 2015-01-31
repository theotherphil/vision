
import std.csv;
import std.conv;
import std.datetime;
import std.file;
import std.math;
import std.path;
import std.range;
import std.stdio;
import std.string;

import ae.utils.graphics.color;
import ae.utils.graphics.image;
import ae.utils.graphics.draw;

import image.contrast;
import image.features;
import image.filter;
import image.io;
import image.util;
import image.viewrange;

import gtsrb;

string devDir = "/Users/philip/dev/";
string outDir = "/Users/philip/dev/temp/";

string temp(string file)
{
	return buildPath(outDir, file);
}

void main()
{
	auto dur = benchmark!runSigns(1);
	writeln("Time taken: ", to!Duration(dur[0]));
}

void runSigns()
{
	score(new ConstantSignTrainer(0), 10);
}

void runHog()
{
	auto image = 
		readPNG(outDir ~ "house.png")
			.toGreyscale
			.crop(0, 0, 500, 350);
	
	auto opts = HogOptions(8, true, 10, 2, 1);
	
	histGrid(image, opts).visualise(20, true, 350.0).writePNG(temp("hog"));
	//star(150, [1.0, 2.0, 3.0, 4.0, 3.0, 2.0, 1.0], true, 1.0).writePNG(temp("star"));
}