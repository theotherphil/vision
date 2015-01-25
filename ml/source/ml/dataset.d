module ml.dataset;

import std.range;

///
enum isDataSet(D) = isLabelSet!(LabelSet!D) && isValueSet!(ValueSet!D);

///
alias LabelSet(T) = typeof(T.init.labels);

///
alias ValueSet(T) = typeof(T.init.values);

///
alias ValueType(D) = ElementType!(ValueSet!D);

///
enum isLabelSet(T) = isFiniteRandomAccessRange!T && is (ElementType!T : uint);

///
enum isValueSet(D) = isFiniteRandomAccessRange!D;

/// 
enum isFiniteRandomAccessRange(R) = !isInfinite!R && isRandomAccessRange!R;

