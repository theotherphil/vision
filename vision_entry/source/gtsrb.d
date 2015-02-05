module gtsrb;

import std.algorithm;
import std.array;
import std.conv;
import std.csv;
import std.datetime;
import std.file;
import std.path;
import std.range;
import std.stdio;
import std.string;

import ae.utils.graphics.image;
import ae.utils.graphics.draw;
import ae.utils.graphics.color;

import image.io;
import image.features;

import ml.forest;

// Implementation of "Traffic Sign Classification using K-d trees 
// and Random Forests", Zaklouta et al, with test harness for
// the GTSRB http://benchmark.ini.rub.de.

// Local directory structure:
// GTSRB
//
// 	Test
// 		GT-final_test.csv
//		00000.ppm
//  	...
//
//	Training
//		00000
//			GT-00000.csv
//			00000_00001.ppm
//			...
//		...
//		00039
//			GT-00039.csv
//			00000_00001.ppm
//			...
//
// Within each training directory the first section of each
// filename corresponds to a single physical roadsign
//
// csv file format: 
// Filename, Width, Height, Roi.X1, Roi.Y1, Roi.X2, Roi.Y2, ClassId

string[] dirs(string rootDir)
{
	return dirEntries(rootDir, SpanMode.shallow).filter!(x => isDir(x)).map!(x => x.name).array;
}

static string rootDir = "/Users/philip/dev/data/GTSRB";

void logTime(string name, TickDuration dur)
{
	writefln("Time taken by %s: %s", name, to!Duration(dur));
}

void logLoadFail(string path)
{
	writeln("Failed to load ", path);
}

SignClassifier train(SignTrainer trainer, int maxSamplesPerClass)
{
	auto t = measureTime!(d => logTime("training", d));

	writeln("**** TRAINING ****");
	auto trainDirs = dirs(buildPath(rootDir, "Training"));
	auto numTrained = 0;

	foreach (dir; trainDirs)
	{
		writeln("Processing ", dir);
		
		auto cat = baseName(dir).to!int;
		auto csv = format("GT-%s.csv", baseName(dir));
		auto records = readRecords(buildPath(dir, csv));	
		
		import std.stdio;

		auto classSamples = 0;
		foreach(f, r; records)
		{
			if (++classSamples > maxSamplesPerClass)
				break;
				
			auto p = buildPath(dir, f);
			
			try
			{
				trainer.add(readPBM(p), rect(r), r.classId);
				++numTrained;
			}
			catch(Exception ex)
			{
				logLoadFail(p);
			}
		}
	}

	writeln("Trained on ", numTrained, " images");
	auto u = measureTime!(d => logTime("train forest", d));
	return trainer.train();
}

void test(SignClassifier classifier, int maxTestImages)
{
	auto timeTesting = measureTime!(d => logTime("testing", d));
	writeln("**** TESTING ****");
	auto testDir = buildPath(rootDir, "Test");
	auto testCsv = buildPath(testDir, "GT-final_test.csv");
	
	auto win = 0;
	auto fail = 0;
	
	auto records = readRecords(testCsv);

	auto count = 0;
	foreach (f, r; records)
	{
		if (++count > maxTestImages)
			break;

		auto p = buildPath(testDir, f);
		auto result = classifier.classify(readPBM(p), rect(r));
		
		if (result == r.classId)
			win++;
		else
			fail++;
	}
	
	auto total = win + fail;
	writefln("Tested on %s images. Win: %s, fail: %s. Accuracy: %s", total, win, fail, cast(double)win/total);
}

void score(SignTrainer trainer, int maxSamplesPerClass, int maxTestImages)
{
	test(train(trainer, maxSamplesPerClass), maxTestImages);
}

private Rect rect(RoiRecord r)
{
	return Rect(r.x1, r.y1, r.x2, r.y2);
}

struct Rect
{
	int x0; int y0; int x1; int y1;
}

interface SignTrainer
{
	void add(Image!RGB sign, Rect box, int category);

	SignClassifier train();
}

class ForestSignClassifier : SignClassifier
{
	this(DecisionForest forest, HogOptions options)
	{
		_forest = forest;
		_options = options;
	}

	int classify(Image!RGB sign, Rect box)
	{
		auto feat = hogFeature(sign, _options);
		return _forest.classify(feat)[0].to!int;
	}

	private DecisionForest _forest;
	private HogOptions _options;
}

double[] hogFeature(Image!RGB sign, HogOptions options)
{
	return hog(sign.toGreyscale.nearestNeighbor(40, 40), options);
}

class ForestSignTrainer(C) : SignTrainer
{
	this(TreeTrainer!C trainer, uint numTrees, HogOptions options)
	{
		_trainer = trainer;
		_numTrees = numTrees;
		_options = options;
	}

	void add(Image!RGB sign, Rect box, int category)
	{
		auto feat = hogFeature(sign, _options);
		_features ~= feat;
		_labels ~= category;
	}

	SignClassifier train()
	{
		auto forest = trainForest(DataView(_features, _labels), _trainer, _numTrees);
		return new ForestSignClassifier(forest, _options);
	}

	private double[][] _features;
	private uint[] _labels;
	private uint _numTrees;
	private HogOptions _options;
	private TreeTrainer!C _trainer;
}

class ConstantSignTrainer : SignTrainer
{
	this(int category)
	{
		_category = category;
	}

	void add(Image!RGB sign, Rect box, int category)
	{
		// Do nothing!
	}

	SignClassifier train()
	{
		return new ConstantClassifier(_category);
	}

	private int _category;
}

interface SignClassifier
{
	int classify(Image!RGB sign, Rect box);
}

class ConstantClassifier : SignClassifier
{
	this(int category)
	{
		_category = category;
	}

	int classify(Image!RGB sign, Rect box)
	{
		return _category;
	}

	private int _category;
}

struct RoiRecord
{
	string filename;
	int width;
	int height;
	int x1;
	int y1;
	int x2;
	int y2;
	int classId;
	
	string toString() const pure @safe
	{
		auto app = appender!string();
		
		app.put("RoiRecord: ");
		app.put(format("filename: %s, ", filename));
		app.put(format("width: %s, ", width));
		app.put(format("height: %s, ", height));
		app.put(format("x1: %s, ", x1));
		app.put(format("y1: %s, ", y1));
		app.put(format("x2: %s, ", x2));
		app.put(format("y2: %s, ", y2));
		app.put(format("classId: %s", classId));
		
		return app.data;
	}  
}

RoiRecord[string] readRecords(string csvPath)
{
	RoiRecord[string] records;
	
	auto header = ["Filename", "Width", "Height", "Roi.X1", "Roi.Y1", "Roi.X2", "Roi.Y2", "ClassId"];
	auto text = std.file.readText(csvPath);
	
	foreach (record; csvReader!RoiRecord(text, header, ';'))
		records[record.filename] = record;
	
	return records;
}


