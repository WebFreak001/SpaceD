module systems.display;

import avocado.core;
import avocado.gl3;
import avocado.dfs;

import app;
import text;
import components;
import particles;
import scenemanager;

import std.algorithm;
import std.conv;

alias SkyboxMesh = GL3Mesh!(PositionElement, TexCoordElement);

class DisplaySystem : ISystem
{
public:
	this(Renderer renderer, View window, ParticleSystem!(2048) particles, Font font,
			Shader textShader, ResourceManager res, SceneManager sceneManager)
	{
		this.renderer = renderer;
		this.window = window;
		this.particles = particles;
		text = new Text(font, textShader);
		this.sceneManager = sceneManager;

		skyboxMesh = new SkyboxMesh();
		{ // Skybox
			//dfmt off
			enum w1 = 1/3.0f;
			enum w2 = 2/3.0f;
			enum h = 0.5f;
			skyboxMesh.addPositionArray([
				vec3(-50.0f, 50.0f, 50.0f), // left
				vec3(-50.0f, 50.0f,-50.0f),
				vec3(-50.0f,-50.0f, 50.0f),
				vec3(-50.0f, 50.0f,-50.0f),
				vec3(-50.0f,-50.0f,-50.0f),
				vec3(-50.0f,-50.0f, 50.0f),
				vec3(-50.0f, 50.0f,-50.0f), // front
				vec3( 50.0f, 50.0f,-50.0f),
				vec3(-50.0f,-50.0f,-50.0f),
				vec3( 50.0f, 50.0f,-50.0f),
				vec3( 50.0f,-50.0f,-50.0f),
				vec3(-50.0f,-50.0f,-50.0f),
				vec3( 50.0f, 50.0f,-50.0f), // right
				vec3( 50.0f, 50.0f, 50.0f),
				vec3( 50.0f,-50.0f,-50.0f),
				vec3( 50.0f, 50.0f, 50.0f),
				vec3( 50.0f,-50.0f, 50.0f),
				vec3( 50.0f,-50.0f,-50.0f),
				vec3( 50.0f, 50.0f, 50.0f), // back
				vec3(-50.0f, 50.0f, 50.0f),
				vec3( 50.0f,-50.0f, 50.0f),
				vec3(-50.0f, 50.0f, 50.0f),
				vec3(-50.0f,-50.0f, 50.0f),
				vec3( 50.0f,-50.0f, 50.0f),
				vec3(-50.0f, 50.0f, 50.0f), // top
				vec3( 50.0f, 50.0f, 50.0f),
				vec3(-50.0f, 50.0f,-50.0f),
				vec3( 50.0f, 50.0f, 50.0f),
				vec3( 50.0f, 50.0f,-50.0f),
				vec3(-50.0f, 50.0f,-50.0f),
				vec3(-50.0f,-50.0f,-50.0f), // bottom
				vec3( 50.0f,-50.0f,-50.0f),
				vec3(-50.0f,-50.0f, 50.0f),
				vec3( 50.0f,-50.0f,-50.0f),
				vec3( 50.0f,-50.0f, 50.0f),
				vec3(-50.0f,-50.0f, 50.0f),
			]);
			skyboxMesh.addTexCoordArray([
				vec2(0, 0), // left
				vec2(w1, 0),
				vec2(0, h),
				vec2(w1, 0),
				vec2(w1, h),
				vec2(0, h),
				vec2(w1, 0), // front
				vec2(w2, 0),
				vec2(w1, h),
				vec2(w2, 0),
				vec2(w2, h),
				vec2(w1, h),
				vec2(w2, 0), // right
				vec2(1, 0),
				vec2(w2, h),
				vec2(1, 0),
				vec2(1, h),
				vec2(w2, h),
				vec2(0, h), // back
				vec2(w1, h),
				vec2(0, 1),
				vec2(w1, h),
				vec2(w1, 1),
				vec2(0, 1),
				vec2(w1, h), // top
				vec2(w2, h),
				vec2(w1, 1),
				vec2(w2, h),
				vec2(w2, 1),
				vec2(w1, 1),
				vec2(w2, h), // bottom
				vec2(1, h),
				vec2(w2, 1),
				vec2(1, h),
				vec2(1, 1),
				vec2(w2, 1),
			]);
			skyboxMesh.generate();
			//dfmt on
		}

		foreach (i, ref tex; places)
			tex = res.load!Texture("textures/place-" ~ (i + 1).to!string ~ ".png");
	}

	final void update(World world)
	{
		renderer.begin(window);
		renderer.enableBlend();
		renderer.clear();
		particles.update(world.delta);
		float camRotation;
		RaceInfo* raceInfo;
		VehiclePhysics*[] allPlayers;
		ubyte lap = 0;
		foreach (entity; world.entities)
		{
			if (entity.alive)
			{
				entity.fetch(raceInfo);
				{
					EntityDisplay display;
					Transformation transform;
					if (entity.fetch(transform, display))
					{
						renderer.modelview.push();
						renderer.modelview.top *= transform.transform * display.matrix;
						display.texture.bind(renderer, 0);
						renderer.bind(display.shader);
						renderer.drawMesh(display.mesh);
						renderer.modelview.pop();
					}
				}
				{
					VehiclePhysics* phys;
					if (entity.fetch(phys))
					{
						if (entity.has!PlayerControls)
						{
							camRotation = phys.cameraRotation;
							lap = cast(ubyte)(phys.currentCheckpoint / max(1, phys.numCheckpoints) + 1);
							phys.player = true;
						}
						allPlayers ~= phys;
					}
				}
				{
					ParticleSpawner* spawner;
					if (entity.fetch(spawner))
					{
						if (spawner.toSpawn.length)
						{
							foreach (part; spawner.toSpawn)
								particles.spawnParticle(part.pos, part.tex, part.info);
							spawner.toSpawn.length = 0;
						}
					}
				}
				{
					Skybox skybox;
					if (entity.fetch(skybox))
					{
						renderer.disableDepthTest();
						renderer.modelview.push();
						renderer.modelview[0][3] = 0;
						renderer.modelview[1][3] = 0;
						renderer.modelview[2][3] = 0;
						skybox.texture.bind(renderer, 0);
						renderer.bind(skybox.shader);
						renderer.drawMesh(skyboxMesh);
						renderer.modelview.pop();
						renderer.enableDepthTest();
					}
				}
			}
		}
		particles.draw(renderer, camRotation);
		renderer.bind2D();
		renderer.modelview.push();
		renderer.modelview = mat4.identity;
		drawRacingUI(lap, allPlayers, raceInfo);
		renderer.modelview.pop();
		renderer.bind3D();
		renderer.end(window);
		if (lap > maxLaps)
			sceneManager.setScene("leaderboards");
	}

	void drawRacingUI(ubyte lap, VehiclePhysics*[] allPlayers, RaceInfo* raceInfo)
	{
		if (raceInfo.time < 0)
		{
			int sec = cast(int)-raceInfo.time + 1;
			renderer.modelview.push();
			text.text = sec.to!dstring;
			renderer.modelview.top *= mat4.translation(window.width / 2 - text.textWidth * 768 * 2,
					window.height / 2, 0) * mat4.scaling(768 * 4, 512 * 4, 1);
			text.draw(renderer);
			renderer.modelview.pop();
		}
		renderer.modelview.push();
		renderer.modelview.top *= mat4.translation(20, window.height - 20, 0) * mat4.scaling(768,
				512, 1);
		text.text = "Lap "d ~ lap.to!dstring ~ " / "d ~ maxLaps.to!dstring;
		text.draw(renderer);
		renderer.modelview.pop();

		int place = 0;
		foreach (ref player; allPlayers)
		{
			if (player.lastCheck != player.currentCheckpoint)
			{
				ubyte tmpPlace = 0;
				foreach (a; allPlayers.sort!"a.currentCheckpoint == b.currentCheckpoint ?
					a.place < b.place :
					a.currentCheckpoint > b.currentCheckpoint")
				{
					a.place = ++tmpPlace;
					a.lastCheck = a.currentCheckpoint;
				}
				break;
			}
		}
		foreach (ref p; allPlayers)
			if (p.player)
			{
				place = p.place;
				break;
			}
		auto size = window.width / 8;
		renderer.drawRectangle(places[min(max(place - 1, 0), $)],
				vec4(window.width - 20 - size, window.height - 20 - size, size, size));
	}

private:
	Renderer renderer;
	View window;
	Texture[8] places;
	ParticleSystem!(2048) particles;
	SkyboxMesh skyboxMesh;
	SceneManager sceneManager;
	Text text;
	ubyte maxLaps = 1;
}
