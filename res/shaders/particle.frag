#version 330
uniform sampler2D tex0;
uniform sampler2D tex1;
in vec2 texCoord;
flat in int texIndex;
in vec4 color;

layout(location = 0) out vec4 out_frag_color;

void main()
{
	vec4 col;
	if (texIndex == 0)
		col = texture(tex0, texCoord);
	else
		col = texture(tex1, texCoord);
	if (col.a < 0.1)
		discard;
	out_frag_color = color * col;
}