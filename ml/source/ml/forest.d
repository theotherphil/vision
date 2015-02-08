module ml.forest;

import std.algorithm;
import std.math;
import std.range;
import std.random;
import std.typecons;
import std.variant;

import ml.dataset;
import ml.math;

struct DataView
{
	double[][] values;
	uint[] labels;

	size_t length()
	{
		return values.length;
	}

	this(double[][] values, uint[] labels)
	{
		assert(values.length == labels.length, "values and labels have different lengths");

		this.values = values;
		this.labels = labels;
	}
}

static assert(isDataSet!DataView);

struct Split
{
	DataView left; DataView right; double score;
}

enum isBinaryClassifier(T) = 
	is (typeof(T.classify((double[]).init)) == bool);

Tuple!(DataView, DataView) split(C)(C classifier, DataView data)
	if (isBinaryClassifier!C)
{
	double[][] leftValues;  uint[] leftLabels;
	double[][] rightValues; uint[] rightLabels;

	for (auto i = 0; i < data.values.length; ++i)
	{
		auto left = classifier.classify(data.values[i]);
		if (left)
		{
			leftValues  ~= data.values[i];
			leftLabels  ~= data.labels[i];
		}
		else
		{
			rightValues ~= data.values[i];
			rightLabels ~= data.labels[i];
		}
	}

	auto left  = DataView(leftValues,  leftLabels);
	auto right = DataView(rightValues, rightLabels);

	return tuple(left, right);
}

/// Checks if descriptor[splitIndex] > threshold.
struct Stump
{
	size_t splitIndex; double threshold;

	this(size_t idx, double thresh)
	{
		splitIndex = idx;
		threshold = thresh;
	}

	bool classify(double[] descriptor)
	{
		return descriptor[splitIndex] > threshold;
	}
}

static assert(isBinaryClassifier!Stump);

unittest
{
	auto stump = Stump(0, 1.0);
	
	assert(stump.classify([0.0, 5.0]) == false);
	assert(stump.classify([5.0, 0.0]) == true);

	auto data  = DataView([[0.0],[2.0],[-1.0],[7.0]], [1, 2, 3, 4]);
	auto split = split(stump, data);

	assert(split[0] == DataView([[2.0], [7.0]], [2, 4]));
	assert(split[1] == DataView([[0.0], [-1.0]], [1,3]));
}

// TODO: require f :: DataView -> DataView -> DataView -> double
Tuple!(ElementType!R, Split) minimise(alias fun, R)(R classifiers, DataView data)
	if (isInputRange!R && isBinaryClassifier!(ElementType!R))
{
	assert(!classifiers.empty, "Cannot choose from empty set of candidates");

	ElementType!R bestClassifier;
	auto bestSplit = Split(DataView.init, DataView.init, double.infinity);

	foreach (c; classifiers)
	{
		auto split = split(c, data);
		auto score = fun(data, split[0], split[1]);
		if (score < bestSplit.score)
		{
			bestClassifier = c;
			bestSplit = Split(split[0], split[1], score);
		}
	}
	
	return tuple(bestClassifier, bestSplit);
}

unittest
{
	auto values = [[1.0, 1.0], [2.0, -2.0], [-1.0, -1.0], [-2.0, 2.0]];
	auto labels = [1u, 1u, 2u, 2u];
	auto data   = DataView(values, labels);

	auto s0 = new Stump(0, 0.0);
	auto s1 = new Stump(1, 0.0);

	double sizeDiff(DataView n, DataView l, DataView r)
	{
		return abs(l.length - r.length);
	}

	auto min = minimise!sizeDiff([s0, s1], data);

	assert(min[0] is s0);
}

// H(data) - |right| * H(right) - |left| * H(left)
double weightedEntropyDrop(D)(D node, D left, D right, uint numClasses)
	if (isDataSet!D)
{
	auto weightedLeft = entropy(left.labels, numClasses) * left.length;
	auto weightedRight = entropy(right.labels, numClasses) * right.length;
	return entropy(node.labels, numClasses) - weightedLeft - weightedRight;
}

interface ClassifierSelector(C)
	if (isBinaryClassifier!C)
{
	Tuple!(C, Split) select(InputRange!C classifiers, DataView data);
}

/// Chooses the classifier which maximises the reduction in weighted entropy,
/// i.e. which maximises H(data) - |R| * H(R) - |L| * H(L)
class EntropyMinimiser(C) : ClassifierSelector!C
{
	uint _numClasses;

	this(uint numClasses)
	{
		_numClasses = numClasses;
	}

	Tuple!(C, Split) select(InputRange!C classifiers, DataView data)
	{
		return minimise!((n, l, r) => -weightedEntropyDrop(n, l, r, _numClasses))(classifiers, data);
	}
}

/// Generates Stumps with the query dimension generated uniformly
/// in [0, numDims) and the threshold generated uniformly in [min, max) 
struct StumpGenerator
{
	this(int numDims, double min, double max, int seed = 1)
	{
		_numDims = numDims;
		_min = min;
		_max = max;
		_rand = Random(seed);
		_front = gen();
	}

	bool empty()
	{ 
		return false; 
	}

	void popFront()
	{ 
		_front = gen(); 
	}

	Stump front()
	{
		return _front;
	}

	Stump gen()
	{
		return Stump(nextIndex, nextThreshold);
	}

	private int nextIndex()
	{
		return uniform(0, _numDims, _rand);
	}
	
	private double nextThreshold()
	{
		return uniform(_min, _max, _rand);
	}

	private int _numDims;
	private double _min;
	private double _max;
	private Random _rand;
	private Stump _front;
}

/// Probability distribution over class labels
struct ClassDistribution
{
	double[] probabilities;

	this(double[] probabilities)
	{
		this.probabilities = probabilities;
	}
}

ClassDistribution distribution(L)(L labels, uint numClasses)
	if (isLabelSet!L)
{
	double[] probabilities = new double[numClasses];
	probabilities[] = 0.0;

	foreach (label; labels)
		probabilities[label] += 1.0;

	foreach (ref count; probabilities)
		count /= labels.length;

	return ClassDistribution(probabilities);
}

unittest
{
	auto labels = [0, 1, 2, 0];
	auto dist   = distribution(labels, 4u);

	assert(dist.probabilities == [0.5, 0.25, 0.25, 0]);
}

interface DecisionTree
{
	ClassDistribution classify(double[] sample);
}

// Either (left, right) both non-null or both null.
// Dist is null iff (left, right) non-null
class TreeNode(C)
{
	C classifier;
	TreeNode left;
	TreeNode right;
	Nullable!ClassDistribution dist;
}

auto treeNode(C)(C c, TreeNode!C l, TreeNode!C r, ClassDistribution d)
{
	return new TreeNode!C(c, l, r, d);
}

class Tree(C) : DecisionTree
{
	this(TreeNode!C root)
	{
		this.root = root;
	}

	ClassDistribution classify(double[] sample)
	{
		auto current = root;
		while (current.dist.isNull)
		{
			current = current.classifier.classify(sample)
				? current.left
				: current.right;
		}
		return current.dist;
	}

	TreeNode!C root;
}

interface StopRule
{
	bool reject(Split split, uint depth);
}

class DepthLimit : StopRule
{
	this(uint limit)
	{
		_limit = limit;
	}

	bool reject(Split split, uint depth)
	{
		return depth > _limit;
	}

	private uint _limit;
}

struct TreeTrainingParams(C)
{
	int candidatesPerNode;
	InputRange!C generator;
	ClassifierSelector!C selector;
	StopRule stopRule;
}

auto treeTrainingParams(C)(
	int candidatesPerNode, InputRange!C generator,
	ClassifierSelector!C selector, StopRule stopRule)
{
	return TreeTrainingParams!C(
		candidatesPerNode, generator, selector, stopRule);
}

struct TreeTrainer(C)
{
	uint _numClasses;
	TreeTrainingParams!C _params;

	this (uint numClasses, TreeTrainingParams!C params)
	{
		_numClasses = numClasses;
		_params = params;
	}

	DecisionTree trainTree(DataView data)
	{
		auto root = new TreeNode!C();
		growTree(root, data, 1);
		return new Tree!C(root);
	}

	void growTree(TreeNode!C node, DataView data, uint currentDepth)
	{
		auto candidates = _params.generator.take(_params.candidatesPerNode);
		auto selection  = _params.selector.select(candidates.inputRangeObject, data);
		
		auto classifier = selection[0];
		auto split 		= selection[1];
		
		if (_params.stopRule.reject(split, currentDepth))
		{
			node.dist = distribution(data.labels, _numClasses);
		}
		else
		{
			node.classifier = classifier;

			node.left = new TreeNode!C();
			growTree(node.left, split.left, currentDepth + 1);

			node.right = new TreeNode!C();
			growTree(node.right, split.right, currentDepth + 1);
		}
	}
}

unittest
{
	struct ReturnTrue
	{
		bool classify(double[] sample) { return true; }
	}
	
	static assert(isBinaryClassifier!ReturnTrue);

	// Returns first classifier it's given. Splits data in two regardless of input classifiers
	class SelectFirst : ClassifierSelector!ReturnTrue
	{
		Tuple!(ReturnTrue, Split) select(InputRange!ReturnTrue classifiers, DataView data)
		{
			auto length = data.length;
			auto score  = 1.0;
			auto left   = DataView(data.values[0 .. length/2], data.labels[0 .. length/2]);
			auto right  = DataView(data.values[length/2 .. $], data.labels[length/2 .. $]);
			auto split  = Split(left, right, score);

			return tuple(classifiers.front, split);
		}
	}

	struct Constant
	{
		bool empty() { return false;}
		void popFront() { }
		ReturnTrue front() { return ReturnTrue(); }
	}

	auto params  = TreeTrainingParams!ReturnTrue(1, Constant().inputRangeObject, new SelectFirst, new DepthLimit(2));

	auto trainer = TreeTrainer!ReturnTrue(4, params);
	auto data    = DataView([[0.0], [1.0], [2.0], [3.0]], [0, 1, 2, 3]);

	auto tree    = trainer.trainTree(data);
	auto dist    = tree.classify([0.0]);

	// This is a bit of a crap check - I've set up the tree to always return true...
	assert(tree.classify([0.0]).probabilities == [1.0, 0.0, 0.0, 0.0]);
}

interface DecisionForest
{
	/// Returns class label and confidence \in [0,1]
	Tuple!(uint,double) classify(double[] sample);
}

// TODO: weight results by frequency of classes in input
class Forest : DecisionForest
{
	this(DecisionTree[] trees)
	{
		_trees = trees;
	}

	Tuple!(uint,double) classify(double[] sample)
	{
		auto dists = new ClassDistribution[_trees.length];
		for (auto i = 0; i < _trees.length; ++i)
			dists[i] = _trees[i].classify(sample);

		auto summed     = sum(dists);
		auto bestGuess  = cast(uint)argMax(summed);
		auto confidence = summed[bestGuess];

		return tuple(bestGuess, confidence);
	}

	double[] sum(ClassDistribution[] dists)
	{
		auto summed = dists[0].probabilities;
		for (auto i = 1; i < dists.length; ++i)
			summed[] += dists[i].probabilities[];
		summed[] /= summed.sum();
		return summed;
	}

	private DecisionTree[] _trees;
	private uint _numClasses;
}

DecisionForest trainForest(C)(DataView data, TreeTrainer!C trainer, uint numTrees)
{
	DecisionTree[] trees = new DecisionTree[numTrees];

	for (int i = 0; i < numTrees; ++i)
	{
		trees[i] = trainer.trainTree(data);
		import std.stdio;
		writeln("Trained tree ", i);
	}

	return new Forest(trees);
}