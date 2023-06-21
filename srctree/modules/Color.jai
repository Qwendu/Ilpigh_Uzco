#scope_export


Color :: struct
{
	r : float;
	g : float;
	b : float;
	a : float;
	#place r;
	using vec : float4 = ---;
};


RED    :: Color.{1,0,0,0};
GREEN  :: Color.{0,1,0,0};
BLUE   :: Color.{0,0,1,0};
PURPLE :: Color.{1,0,1,0};


operator * :: (l : Color, r : Color) -> Color
{
	res := l;
	res.r *= r.r;
	res.g *= r.g;
	res.b *= r.b;
	res.a *= r.a;
	return res;
}


#import "Vector";
