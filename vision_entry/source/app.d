
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

import ml.forest;

import gtsrb;

static string outDir = "/Users/philip/dev/temp/";

string temp(string file)
{
	return buildPath(outDir, file);
}

void main()
{	
	writefln("Entered main");
	auto dur = benchmark!runSigns(1);
	writeln("Time taken: ", to!Duration(dur[0]));
}

void runSigns()
{
	int maxSamplePerClass = 10;
	int maxTestImages = 100;
	int candidatesPerNode = 1000;
	int depthLimit = 8;
	int numTrees = 1;
	uint numClasses = 43;

	auto generator = new StumpGenerator(hogSize(40, 40, defaultHog), 0, 1);

	auto params = TreeTrainingParams(
		candidatesPerNode, generator, new EntropyMinimiser(numClasses), new DepthLimit(depthLimit));

	auto treeTrainer = DecisionTreeTrainer(numClasses, params);
	auto signTrainer = new ForestSignTrainer(treeTrainer, cast(uint)numTrees, defaultHog);

	score(signTrainer, maxSamplePerClass, maxTestImages);
	//score(new ConstantSignTrainer(0), maxSamplePerClass, maxTestImages);
}

HogOptions defaultHog()
{
	return HogOptions(8, true, 5, 2, 1);
} 

void runHog()
{
	auto image = 
		readPNG(outDir ~ "house.png")
			.toGreyscale
			.crop(0, 0, 500, 350);
	
	auto opts = HogOptions(8, true, 10, 2, 1);
	
	histGrid(image, opts).visualise(20, true).writePNG(temp("hog"));
	//star(150, [1.0, 2.0, 3.0, 4.0, 3.0, 2.0, 1.0], true, 1.0).writePNG(temp("star"));
}