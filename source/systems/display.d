module systems.display;

import avocado.core;

import app;
import components;
import particles;

class DisplaySystem : ISystem
{
public:
	this(Renderer renderer, View window, ParticleSystem!() particles)
	{
		this.renderer = renderer;
		this.window = window;
		this.particles = particles;
	}

	final void update(World world)
	{
		renderer.begin(window);
		renderer.clear();
		particles.update(world.delta);
		float camRotation;
		foreach (entity; world.entities)
		{
			if (entity.alive)
			{
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
					VehiclePhysics phys;
					if (entity.fetch(phys))
						camRotation = phys.cameraRotation;
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
			}
		}
		particles.draw(renderer, camRotation);
		renderer.end(window);
	}

private:
	Renderer renderer;
	View window;
	ParticleSystem!() particles;
}
