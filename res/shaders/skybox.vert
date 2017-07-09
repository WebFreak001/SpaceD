#version 330
layout(location = 0) in vec3 in_position;

uniform mat4 modelview;
uniform mat4 projection;
out vec3 texDir;

void main()
{
	gl_Position = projection * modelview * vec4(in_position, 1);
	texDir = in_position;
}