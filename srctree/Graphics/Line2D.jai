#scope_module


clip_Line :: (start : float2, end : float2, min : float2, max : float2) -> (start : float2, end : float2, succ : bool)
{
	LEFT   :: 1;
	RIGHT  :: 2;
	TOP    :: 4;
	BOTTOM :: 8;
	//https://en.wikipedia.org/wiki/Cohen%E2%80%93Sutherland_algorithm
	outcode_2 :: (a : float2, min : float2, max : float2) -> u8
	{
		res : u8;
		if a.x < min.x  res |= LEFT;
		if a.x > max.x  res |= RIGHT;
		if a.y > max.x  res |= TOP;
		if a.y < min.x  res |= BOTTOM;
		return res;
	}

	start_copy := start;
	end\ _copy := end;
	succ : bool = false;
	out_start_copy := outcode_2(start_copy, min, max);
	out_end_copy   := outcode_2(end_copy, min, max);
	pick_next := 0;
	it := 0;
	while it < 10
	{
		it += 1;
		if out_start_copy == 0 && out_end_copy == 0
		{
			succ = true;
			break;
		}else if (out_start_copy & out_end_copy) != 0
		{
			succ = false;
			break;
		}else if out_start_copy != 0{
			if out_start_copy & TOP
			{
				start_copy.x += (end_copy.x - start_copy.x) * (max.y - start_copy.y)/(end_copy.y - start_copy.y);
				start_copy.y = max.y;
			}else if out_start_copy & BOTTOM
			{
				start_copy.x += (end_copy.x - start_copy.x) * (min.y - start_copy.y)/(end_copy.y - start_copy.y);
				start_copy.y = min.y;
			}else if out_start_copy & RIGHT
			{
				start_copy.y += (end_copy.y - start_copy.y) * (max.x - start_copy.x)/(end_copy.x - start_copy.x);
				start_copy.x = max.x;
			}else if out_start_copy & LEFT
			{
				start_copy.y += (end_copy.y - start_copy.y) * (min.x - start_copy.x)/(end_copy.x - start_copy.x);
				start_copy.x = min.x;
			}
		}else if out_end_copy != 0{
			if out_end_copy & TOP
			{
				end_copy.x += (end_copy.x - start_copy.x) * (max.y - end_copy.y)/(end_copy.y - start_copy.y);
				end_copy.y = max.y;
			}else if out_end_copy & BOTTOM
			{
				end_copy.x += (end_copy.x - start_copy.x) * (min.y - end_copy.y)/(end_copy.y - start_copy.y);
				end_copy.y = min.y;
			}else if out_end_copy & RIGHT
			{
				end_copy.y += (end_copy.y - start_copy.y) * (max.x - end_copy.x)/(end_copy.x - start_copy.x);
				end_copy.x = max.x;
			}else if out_end_copy & LEFT
			{
				end_copy.y += (end_copy.y - start_copy.y) * (min.x - end_copy.x)/(end_copy.x - start_copy.x);
				end_copy.x = min.x;
			}
		}
		out_start_copy = outcode_2(start_copy, min, max);
		out_end\ _copy = outcode_2(end\ _copy, min, max);
	}
	return start_copy, end_copy, succ;
}


render_Line_2D :: (start : float2, end : float2, color : Color, bb : BackBuffer, depth_buffer : [] float)
{
	start_clipped, end_clipped, s := clip_Line(start, end, .{-1,-1}, .{1,1});
	if !s return;
	start_screen := (start_clipped + .{1,1})/2;
	start_screen.x *= bb.size.x;
	start_screen.y *= bb.size.y;
	end_screen   := (end_clipped + .{1,1})/2;
	end_screen.x *= bb.size.x;
	end_screen.y *= bb.size.y;
	delta := end_screen - start_screen;
	len := max(abs(delta.x), abs(delta.y));
	delta /= len;

	runner := start_screen;
	traversed := 0.0;
	while traversed < len
	{
		x := cast(int)runner.x;
		y := cast(int)runner.y;
		if   0 <= x && x < bb.size.x
		  && 0 <= y && y < bb.size.y
		{
			depth_buffer[y * bb.stride + x] = 1;
			bb.data[y * bb.stride + x ] = .{
				r = xx clamp(color.r * 255, 0, 255),
				g = xx clamp(color.g * 255, 0, 255),
				b = xx clamp(color.b * 255, 0, 255)
			};
		}

		runner += delta;
		traversed += 1;
	}
}

render_Bezier_Curve :: (curve : Bezier_Curve(3,2), world_to_projection : float4x4, bb : BackBuffer, depth_buffer : [] float)
{
	assert(curve.subdivisions > 0, "Subdivisions was %, should be more than 0", curve.subdivisions);
	previous_point := curve.control_points[0];
	render :: (a : float3, b : float3) #expand
	{
		pa := project_Point(world_to_projection, a);
		pb := project_Point(world_to_projection, b);
		render_Line_2D(pa.xy, pb.xy, curve.color, bb, depth_buffer);
	}
	for 1..curve.subdivisions-1
	{
		point := interpolate(curve, (cast(float)it)/curve.subdivisions);
		render(previous_point, point);
		previous_point = point;
	}
	render(previous_point, curve.control_points[curve.control_points.count - 1]);
}

render_Bezier_Curve :: (curve : Bezier_Curve(2,2), bb : BackBuffer, depth_buffer : [] float)
{
	assert(curve.subdivisions > 0, "Subdivisions was %, should be more than 0", curve.subdivisions);
	previous_point := curve.control_points[0];
	render :: (a : float2, b : float2) #expand
	{
		render_Line_2D(a, b, curve.color, bb, depth_buffer);
	}
	for 1..curve.subdivisions-1
	{
		point := interpolate(curve, (cast(float)it)/curve.subdivisions);
		render(previous_point, point);
		previous_point = point;
	}
	render(previous_point, curve.control_points[curve.control_points.count - 1]);
}

#import "Bezier";
