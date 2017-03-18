module particles;

import app;

import avocado.core;
import avocado.gl3;
import std.stdio;

alias PositionStream = BufferElement!("ParticlePosition", 3, float, false,
		BufferType.Element, true);
alias TexIndexStream = BufferElement!("TexIndex", 1, int, false, BufferType.Element, true);
alias ColorStream = BufferElement!("Color", 4, float, false, BufferType.Element, true);

alias ParticleStream = GL3Mesh!(PositionElement, PositionStream, TexIndexStream, ColorStream);

struct ParticleInfo
{
	vec4 color;
	float deathtime = 1;
	float gravity = 1;
	vec3 velocity = vec3(0, 10, 0);
	float velocityFalloff = 0;
	float lifetime = 0;
}

class ParticleSystem(ushort ParticlesMax = 512)
{
public:
	this(Shader shader, Texture[] textures)
	{
		this.shader = shader;
		this.textures = textures;
		particles = cast(ParticleStream) new ParticleStream().addPositionArray([vec3(-1,
				-1, 0), vec3(-1, 1, 0), vec3(1, -1, 0), vec3(-1, 1, 0), vec3(1, 1, 0), vec3(1, -1, 0)]).reserveParticlePosition(
				ParticlesMax).reserveTexIndex(ParticlesMax).reserveColor(ParticlesMax).generate();
		particlePositions[] = vec3(0, 0, 0);
	}

	void spawnParticle(vec3 pos, uint tex, ParticleInfo info)
	{
		particlePositions[curParticle] = pos;
		particleTextures[curParticle] = tex;
		particleColors[curParticle] = info.color;
		particleInfos[curParticle] = info;

		static if (ParticlesMax == ubyte.max || ParticlesMax == ushort.max)
			curParticle--; // let it underflow
		else
			curParticle = cast(typeof(curParticle))(curParticle + ParticlesMax - 1) % ParticlesMax;
	}

	void update(float delta)
	{
		for (typeof(curParticle) i = 0; i < ParticlesMax; i++)
		{
			particleInfos[i].velocity -= vec3(0, particleInfos[i].gravity * delta, 0);
			particleInfos[i].velocity *= pow(1 - particleInfos[i].velocityFalloff, delta);
			particleInfos[i].lifetime += delta;
			if (particleInfos[i].lifetime >= particleInfos[i].deathtime)
				particlePositions[i] = vec3(0, 0, 0);
			else
			{
				particleColors[i] = particleInfos[i].color * (
						1 - particleInfos[i].lifetime / particleInfos[i].deathtime);
				particlePositions[i] += particleInfos[i].velocity * delta;
			}
		}
	}

	void draw(Renderer renderer, float camRotation)
	{
		renderer.bind(shader);
		foreach (i, tex; textures)
			renderer.bind(tex, cast(int) i);
		particles.fillParticlePosition(particlePositions);
		particles.fillTexIndex(particleTextures);
		particles.fillColor(particleColors);
		shader.set("orientation", mat4.yrotation(camRotation));
		renderer.drawMeshInstanced(particles, ParticlesMax);
	}

	void clear()
	{
		particlePositions[] = vec3(0);
		particleColors[] = vec4(0);
	}

	Texture[] textures;
private:
	ParticleStream particles;
	Shader shader;

	vec3[ParticlesMax] particlePositions;
	int[ParticlesMax] particleTextures;
	vec4[ParticlesMax] particleColors;
	ParticleInfo[ParticlesMax] particleInfos;
	static if (ParticlesMax == ubyte.max)
		ubyte curParticle;
	else
		ushort curParticle;
}
