#version 330
uniform sampler2D tex;
uniform vec4 color;
in vec2 texCoord;

layout(location = 0) out vec4 out_frag_color;

// Text Shader might change
void main()
{
	out_frag_color = texture(tex, texCoord) * color;
}