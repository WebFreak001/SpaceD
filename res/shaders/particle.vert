#version 330
layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_partpos;
layout(location = 2) in int in_tex;
layout(location = 3) in vec4 in_color;

uniform mat4 modelview;
uniform mat4 projection;
uniform mat4 orientation;
out vec2 texCoord;
flat out int texIndex;
out vec4 color;

void main()
{
	gl_Position = projection * modelview * vec4((vec4(in_position, 1) * orientation).xyz * in_color.a + in_partpos, 1);
	texCoord = in_position.xy * 0.5 + 0.5;
	texIndex = in_tex;
	color = in_color;
}