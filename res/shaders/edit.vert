#version 330
layout(location = 0) in vec2 in_position;
layout(location = 1) in vec2 in_texCoord;
layout(location = 2) in int in_selected;

uniform mat4 modelview;
uniform mat4 projection;
out vec2 texCoord;
out float selected;

void main()
{
	gl_Position = projection * modelview * vec4(in_position.x, 0, in_position.y, 1);
	texCoord = in_texCoord;
	selected = in_selected * 1.0;
}