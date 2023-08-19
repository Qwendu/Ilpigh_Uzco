#scope_export

PredicatedArrayView :: struct(T : Type)
{
	predicates : [] bool;
	elements   : [] T;
};

PredicatedArray :: struct(N : int, T : Type)
{
	predicates : [N] bool;
	elements   : [N] T;
};

PredicatedAutoArray :: struct(T : Type)
{
	predicates : [..] bool;
	elements   : [..] T;
};


PredicatedArrayInterface :: struct(T : Type)
{
	predicates : T;
	elements   : T;
}


get :: (arr : *$T/interface PredicatedArrayInterface(T.T), idx : int) -> *arr.T
{
	assert(0 <= idx && idx < arr.predicates.count);
	assert(0 <= idx && idx < arr.elements  .count);

	if idx < 0 || idx >= arr.elements.count  return null;
	if !arr.predicates[idx]  return null;

	return *arr.elements[idx];
}

add :: (arr : *PredicatedAutoArray($T), value : T) -> int
{
	assert(arr.predicates.count == arr.elements.count);

	array_add(*arr.predicates, true);
	array_add(*arr.elements, value);

	return arr.elements.count - 1;
}

get_Slot :: (arr : *PredicatedAutoArray($T)) -> int
{
	assert(arr.predicates.count == arr.elements.count);

	array_add(*arr.predicates, false);
	ptr := array_add(*arr.elements);
	return arr.elements.count - 1;
}

set :: (arr : *$T/interface PredicatedArrayInterface(T.T), idx : int, value : T.T)
{
	assert(0 <= idx && idx < arr.predicates.count);
	assert(0 <= idx && idx < arr.elements  .count);

	arr.predicates[idx] = true;
	arr.elements  [idx] = value;
}



#scope_file
#import "Basic";
