#version 330
uniform sampler2D tex;
in vec2 texCoord;

layout(location = 0) out vec4 out_frag_color;

void main()
{
	vec4 col = texture(tex, texCoord);
	if (col.a < 0.01)
		discard;
	out_frag_color = col;
}