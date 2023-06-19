#scope_export


min :: (a : ..$T) -> T
{
	m := a[0];
	for a  if it < m  m = it;
	return m;
}

max :: (a : ..$T) -> T
{
	m := a[0];
	for a  if it > m  m = it;
	return m;
}


round_Up_To_Multiple :: (number_to_round : int, multiple_of : int) -> int #no_context
{
	n := number_to_round + (multiple_of - 1);
	n /= multiple_of;
	n *= multiple_of;
	return n;
}

round_Up_To_Multiple :: (number_to_round : u64, multiple_of : u64) -> u64 #no_context
{
	n := number_to_round + (multiple_of - 1);
	n /= multiple_of;
	n *= multiple_of;
	return n;
}
