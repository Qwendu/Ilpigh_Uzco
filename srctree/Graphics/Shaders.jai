#scope_export
Occlusion_Shader :: #type (Shader_Input) -> bool;
Pixel_Shader :: #type (Shader_Input, [] Light_Source) -> Shader_Output;

Shader_Global :: struct
{
	camera_position : float3;
	camera_direction : float3;
};

Shader_Input :: struct
{
	position : float3;
	normal : float3;
	depth : float;
	material    : Material;
};

Shader_Output :: struct
{
	color : Color;
};

shader_global : Shader_Global;

depth_shader : Pixel_Shader: (in : Shader_Input, lights : [] Light_Source) -> Shader_Output
{
	using in;
	start := Color.{r=1, g=1, b=1};
	out : Shader_Output;
	out.color = .{vec = start.vec * sqrt(1 - in.depth)};
	return out;
}

color_shader :Pixel_Shader: (in : Shader_Input, lights : [] Light_Source) -> Shader_Output
{
	using in;
	out : Shader_Output;
	out.color = in.material.color;
	return out;
}

fullbright_shader : Pixel_Shader : (in : Shader_Input, lights : [] Light_Source) -> Shader_Output
{
	using in;
	using shader_global;

	out : Shader_Output;
	camera_dot := dot(normalize(position - camera_position, .{}), camera_direction);
	brightness_factor : float = 0.8 + max(camera_dot, 0) * 0.2;
	out.color = material.color * brightness_factor;
	return out;
}

lighted_shader :Pixel_Shader: (in : Shader_Input, lights : [] Light_Source) -> Shader_Output
{
	using in;
	out : Shader_Output;
	out.color = in.material.color;

	light_contribution : Color;
	for light : lights
	{
		delta := light.position - position;
		delta_unit := normalize(delta, .{});
		dist := length_Squared(delta);
		r2  := light.range * light.range;
		if  dist < r2
		{
			frac := (1 - dist/r2) * clamp(dot(normal, delta_unit), 0, 1);
			light_contribution.vec += float4.{frac,frac,frac,1};
		}
	}
	
	out.color *= light_contribution;

	return out;
}
#scope_file

