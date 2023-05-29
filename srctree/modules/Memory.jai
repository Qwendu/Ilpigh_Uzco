

Kilobytes :: (n : int) -> int #expand
{
	return n * 1024;
}

Megabytes :: (n : int) -> int #expand
{
	return Kilobytes(n) * 1024;
}

Gigabytes :: (n : int) -> int #expand
{
	return Megabytes(n) * 1024;
}
