#version 330
layout(location = 1) in vec3 in_position;
layout(location = 2) in vec2 in_tex;
layout(location = 3) in vec3 in_normal;

uniform mat4 modelview;
uniform mat4 model;
uniform mat4 projection;
out vec2 texCoord;
out vec3 normal;
out vec3 vertexWorldPos;
out vec3 worldNormal;

void main()
{
	gl_Position = projection * modelview * vec4(in_position, 1);
	vertexWorldPos = (model * vec4(in_position, 1)).xyz;
	texCoord = in_tex;
	worldNormal = mat3(model) * in_normal;
	normal = normalize(mat3(modelview) * in_normal);
}