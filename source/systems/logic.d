module systems.logic;

import avocado.core;
import avocado.input;

import app;
import components;

class LogicSystem : ISystem
{
public:
	this(Renderer renderer)
	{
		this.renderer = renderer;
	}

	final void update(World world)
	{
		foreach (entity; world.entities)
		{
			if (entity.alive)
			{
				{
					PlayerControls controls;
					Transformation* transform;
					VehiclePhysics* physics;
					if (entity.fetch(transform, controls, physics))
					{
						if (Keyboard.state.isKeyPressed(controls.accelerate))
						{
							physics.linearVelocity += vec2(sin(physics.rotation),
									-cos(physics.rotation)) * world.delta * 50;
						}
						if (Keyboard.state.isKeyPressed(controls.decelerate))
						{
							physics.linearVelocity *= pow(0.5, world.delta);
						}
						if (Keyboard.state.isKeyPressed(controls.steerLeft))
						{
							physics.angularVelocity -= world.delta;
						}
						if (Keyboard.state.isKeyPressed(controls.steerRight))
						{
							physics.angularVelocity += world.delta;
						}
						if (physics.angularVelocity < -1.5f)
							physics.angularVelocity = -1.5f;
						if (physics.angularVelocity > 1.5f)
							physics.angularVelocity = 1.5f;
						physics.angularVelocity *= pow(0.4, world.delta);
						physics.linearVelocity *= pow(0.5, world.delta);
						physics.rotation += physics.angularVelocity * world.delta;
						physics.position += physics.linearVelocity * world.delta;
						transform.transform = mat4.translation(physics.position.x, 0,
								physics.position.y) * mat4.yrotation(-physics.rotation);
						renderer.modelview.top = mat4.xrotation(cradians!20) * mat4.translation(0,
								0, -15) * mat4.yrotation(physics.rotation) * mat4.translation(-physics.position.x,
								-10, -physics.position.y);
					}
				}
			}
		}
	}

private:
	Renderer renderer;
}
