#scope_export

Tebi :: (n : int) -> int #expand
{
	return Gibi(n) * 1024;
}

Gibi :: (n: int) -> int #expand
{
	return Mebi(n) * 1024;
}

Mebi :: (n: int) -> int #expand
{
	return Kibi(n) * 1024;
}

Kibi :: (n: int) -> int #expand
{
	return n * 1024;
}
