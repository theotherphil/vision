module ml.forest;

import std.algorithm;
import std.math;
import std.range;
import std.random;
import std.stdio;
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

struct Split
{
	DataView left; DataView right; double score;
}

enum isBinaryClassifier(T) = 
	is (typeof(T.classify((double[]).init)) == bool);

interface BinaryClassifier
{
	bool classify(double[] sample);
}

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
class Stump : BinaryClassifier
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

unittest
{
	auto stump = new Stump(0, 1.0);
	
	assert(stump.classify([0.0, 5.0]) == false);
	assert(stump.classify([5.0, 0.0]) == true);

	auto data  = DataView([[0.0],[2.0],[-1.0],[7.0]], [1, 2, 3, 4]);
	auto split = split(stump, data);

	assert(split[0] == DataView([[2.0], [7.0]], [2, 4]));
	assert(split[1] == DataView([[0.0], [-1.0]], [1,3]));
}

// TODO: require f :: DataView -> DataView -> DataView -> double
Tuple!(ElementType!R, Split) minimise(alias fun, R)(R classifiers, DataView data)
	if (isInputRange!R && is (ElementType!R == BinaryClassifier))
{
	assert(!classifiers.empty, "Cannot choose from empty set of candidates");
	
	ElementType!R bestClassifier = null;
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
double weightedEntropyDrop(DataView node, DataView left, DataView right, uint numClasses)
{
	auto weightedLeft = entropy(left.labels, numClasses) * left.length;
	auto weightedRight = entropy(right.labels, numClasses) * right.length;
	return entropy(node.labels, numClasses) - weightedLeft - weightedRight;
}

interface ClassifierSelector
{
	Tuple!(BinaryClassifier, Split) select(InputRange!BinaryClassifier classifiers, DataView data);
}

/// Chooses the classifier which maximises the reduction in weighted entropy,
/// i.e. which maximises H(data) - |R| * H(R) - |L| * H(L)
class EntropyMinimiser : ClassifierSelector
{
	uint _numClasses;

	this(uint numClasses)
	{
		_numClasses = numClasses;
	}

	Tuple!(BinaryClassifier, Split) select(InputRange!BinaryClassifier classifiers, DataView data)
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

	BinaryClassifier front()
	{
		return _front;
	}

	BinaryClassifier gen()
	{
		return new Stump(nextIndex, nextThreshold);
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
	private BinaryClassifier _front;
}

/// Probability distribution over class labels
class ClassDistribution
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

	return new ClassDistribution(probabilities);
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
class TreeNode
{
	BinaryClassifier classifier;
	TreeNode left;
	TreeNode right;
	ClassDistribution dist;
}

class Tree : DecisionTree
{
	this(TreeNode root)
	{
		this.root = root;
	}

	ClassDistribution classify(double[] sample)
	{
		auto current = root;
		while (current.dist is null)
		{
			current = current.classifier.classify(sample)
				? current.left
				: current.right;
		}
		return current.dist;
	}

	TreeNode root;
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

struct TreeTrainingParams
{
	int candidatesPerNode;
	InputRange!BinaryClassifier generator;
	ClassifierSelector selector;
	StopRule stopRule;
}

struct DecisionTreeTrainer
{
	uint _numClasses;
	TreeTrainingParams _params;

	this (uint numClasses, TreeTrainingParams params)
	{
		_numClasses = numClasses;
		_params = params;
	}

	DecisionTree trainTree(DataView data)
	{
		auto root = new TreeNode();
		growTree(root, data, 1);
		return new Tree(root);
	}

	void growTree(TreeNode node, DataView data, uint currentDepth)
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

			node.left = new TreeNode();
			growTree(node.left, split.left, currentDepth + 1);

			node.right = new TreeNode();
			growTree(node.right, split.right, currentDepth + 1);
		}
	}
}

unittest
{
	// Returns first classifier its given. Splits data in two regardless of input classifiers
	class SelectFirst : ClassifierSelector
	{
		Tuple!(BinaryClassifier, Split) select(BinaryClassifier[] classifiers, DataView data)
		{
			auto length = data.length;
			auto score  = 1.0;
			auto left   = DataView(data.values[0 .. length/2], data.labels[0 .. length/2]);
			auto right  = DataView(data.values[length/2 .. $], data.labels[length/2 .. $]);
			auto split  = Split(left, right, score);

			return tuple(classifiers[0], split);
		}
	}

	class ReturnTrue : BinaryClassifier
	{
		bool classify(double[] sample) { return true; }
	}

	class Constant : ClassifierGenerator
	{
		BinaryClassifier[] generate(int num)
		{
			BinaryClassifier[] classifiers = new BinaryClassifier[num];
			for (int i = 0; i < num; ++i)
				classifiers[i] = new ReturnTrue;
			return classifiers;
		}
	}

	auto params  = TreeTrainingParams(1, new Constant, new SelectFirst, new DepthLimit(2));

	auto trainer = DecisionTreeTrainer(4, params);
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

DecisionForest trainForest(DataView data, DecisionTreeTrainer trainer, uint numTrees)
{
	DecisionTree[] trees = new DecisionTree[numTrees];

	for (int i = 0; i < numTrees; ++i)
	{
		import std.stdio;
		writeln("Training tree ", i);
		trees[i] = trainer.trainTree(data);
	}

	return new Forest(trees);
}

