module image.attributes;

/// Indicates that we should regression test this
/// function, using the provided non-view args
struct RegressionTested(FuncArgs...)
{
	alias FuncArgs args;
}