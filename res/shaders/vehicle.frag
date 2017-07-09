#version 330
uniform sampler2D tex;
uniform samplerCube skymap;
uniform vec3 cameraWorld;
in vec2 texCoord;
in vec3 normal;
in vec3 vertexWorldPos;
in vec3 worldNormal;

layout(location = 0) out vec4 out_frag_color;

void main()
{
	vec3 lightDir = normalize(vec3(0.5, 0.6, 0.3));
	vec3 cameraDir = normalize(cameraWorld - vertexWorldPos);
	vec3 reflection = reflect(cameraDir, worldNormal);
	vec3 specReflection = reflect(-lightDir, worldNormal);

	float specIntensity = 1024;

	float df = max(0, dot(normal, lightDir)) * 0.95 + 0.05;
	float sf = max(0, dot(specReflection, cameraDir));
	sf = pow(sf, specIntensity) * df;

	float fresnel = 1 - pow(clamp(dot(vec3(0, 0, 1), normal), 0, 1), 0.2);

	vec3 sky = texture(skymap, reflection).rgb;

	vec3 col = texture(tex, texCoord).rgb * df;
	col = col * fresnel + sky * (1 - fresnel) + vec3(3) * sf;

	out_frag_color = vec4(col, texture(tex, texCoord).a);
}
