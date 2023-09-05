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


float_compare :: (a : float, b : float, $comparison : enum {EQ;NEQ;LE;L;GE;G;}) -> bool
{
	// TODO(Qwendo): Shave instructions from this function!!!
	res     : u8;
	// @Cleanup: We might not need these temporaries here!
	//   Remove them
	np      : u8;
	less    : u8;
	greater : u8;
	equal   : u8;
	#asm
	{
		movss a_v: vec, [*a];
		movss b_v: vec, [*b];
		ucomiss a_v, b_v;
		setnp _np      : gpr === a;
		setb  _less    : gpr === b;
		seta  _greater : gpr === c;
		sete  _equal   : gpr === d;
		mov np, _np;
		mov less, _less;
		mov greater, _greater;
		mov equal, _equal;
	}
	if comparison ==
	{
	case .EQ;  res = equal & np;
	case .NEQ; res = ~(equal & np);
	case .LE;  res = (less | equal) & np;
	case .L;   res = less & np;
	case .GE;  res = (greater | equal) & np;
	case .G;   res = greater & np;
	}
	return (res & 1) == 1;
}



choose :: (n : int, k : int) -> int
{
	return factorial(n)/(factorial(k) * factorial(n - k));
}

factorial :: (n : int) -> int
{
	if n <= 0  return 1;
	return factorial(n - 1) * n;
}
