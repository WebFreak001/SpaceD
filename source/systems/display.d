module systems.display;

import avocado.core;

import app;
import components;

class DisplaySystem : ISystem
{
public:
	this(Renderer renderer, View window)
	{
		this.renderer = renderer;
		this.window = window;
	}

	final void update(World world)
	{
		renderer.begin(window);
		renderer.clear();
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
			}
		}
		renderer.end(window);
	}

private:
	Renderer renderer;
	View window;
}
