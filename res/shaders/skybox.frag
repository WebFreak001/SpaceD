#version 330
uniform samplerCube tex;
in vec3 texDir;

layout(location = 0) out vec4 out_frag_color;

void main()
{
	out_frag_color = texture(tex, texDir);
}