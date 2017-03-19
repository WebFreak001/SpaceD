#version 330
uniform sampler2D tex;
in vec2 texCoord;
in float selected;

layout(location = 0) out vec4 out_frag_color;

void main()
{
	if (texCoord.y < 0.1 && (texCoord.x < 0.1 || texCoord.x > 0.9))
	{
		if (selected >= 0.5)
			out_frag_color = vec4(1, 0.5, 0, 1);
		else
			out_frag_color = vec4(0, 0, 1, 1);
	}
	else if (texCoord.x < 0.05 || texCoord.x > 0.95 || texCoord.y < 0.05)
		out_frag_color = vec4(0, 0, 0, 1);
	else
		out_frag_color = vec4(0.5) + texture(tex, texCoord) * 0.5;
}