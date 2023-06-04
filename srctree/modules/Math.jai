#scope_export


min :: (.. a : $T) -> T
{
	m := a[0];
	for a  if it < m  m = it;
	return m;
}

max :: (.. a : $T) -> T
{
	m := a[0];
	for a  if it > m  m = it;
	return m;
}
