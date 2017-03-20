#version 330
uniform sampler2D tex;
in vec2 texCoord;
in vec3 normal;

layout(location = 0) out vec4 out_frag_color;

void main()
{
	vec4 col = texture(tex, texCoord);
	if (col.a < 0.01)
		discard;
	out_frag_color = vec4(
		col.rgb * (clamp(dot(normalize(vec3(0.5, 0.6, 0.3)), normal), 0, 0.75) + 0.25),
		col.a
	);
}