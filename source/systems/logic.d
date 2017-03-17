module systems.logic;

import avocado.core;
import avocado.input;

import app;
import components;
import particles;

private bool lineLineIntersects(vec2 l1a, vec2 l1b, vec2 l2a, vec2 l2b, ref vec2 intersection)
{
	vec2 l1 = l1b - l1a;
	vec2 l2 = l2b - l2a;
	float dot = l1.x * l2.y - l1.y * l2.x;
	if (dot == 0)
		return l1.normalized == l2.normalized;
	vec2 c = l2a - l1a;
	float t = (c.x * l2.y - c.y * l2.x) / dot;
	if (t < 0 || t > 1)
		return false;

	float u = (c.x * l1.y - c.y * l1.x) / dot;
	if (u < 0 || u > 1)
		return false;

	intersection = l1a + t * l1;

	return true;
}

class LogicSystem : ISystem
{
public:
	this(Renderer renderer, View window)
	{
		this.renderer = renderer;
		this.window = window;
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
					ParticleSpawner* particles;
					if (entity.fetch(transform, controls, physics, particles))
					{
						enum HalfFrontWidth = 1;
						enum HalfWidth = 2;
						enum HalfExhaustWidth = 1.5f;
						enum HalfExhaustWidth2 = 1.1f;
						enum HalfHeight = 3.8f;
						auto s = sin(physics.rotation);
						auto c = cos(physics.rotation);
						vec2 tl = vec2(-HalfWidth * c - HalfHeight * s, -HalfWidth * s + HalfHeight * c)
							+ physics.position;
						vec2 tr = vec2(HalfWidth * c - HalfHeight * s, HalfWidth * s + HalfHeight * c)
							+ physics.position;
						vec2 bl = vec2(-HalfFrontWidth * c + HalfHeight * s, -HalfFrontWidth * s - HalfHeight
								* c) + physics.position;
						vec2 br = vec2(HalfFrontWidth * c + HalfHeight * s, HalfFrontWidth * s - HalfHeight * c)
							+ physics.position;
						vec2 exhaustL = vec2(-HalfExhaustWidth * c - HalfHeight * s,
								-HalfExhaustWidth * s + HalfHeight * c) + physics.position;
						vec2 exhaustR = vec2(HalfExhaustWidth * c - HalfHeight * s,
								HalfExhaustWidth * s + HalfHeight * c) + physics.position;
						vec2 exhaustL2 = vec2(-HalfExhaustWidth2 * c - HalfHeight * s,
								-HalfExhaustWidth2 * s + HalfHeight * c) + physics.position;
						vec2 exhaustR2 = vec2(HalfExhaustWidth2 * c - HalfHeight * s,
								HalfExhaustWidth2 * s + HalfHeight * c) + physics.position;

						particles.time += world.delta;
						bool canParticle;
						if (particles.time >= 0.005f)
						{
							canParticle = true;
							particles.time = 0;
						}
						if (Keyboard.state.isKeyPressed(controls.accelerate))
						{
							physics.linearVelocity += vec2(sin(physics.rotation),
									-cos(physics.rotation)) * world.delta * (Keyboard.state.isKeyPressed(controls.boost)
									? 100 : 50);
							physics.reversing = false;

							if (canParticle)
							{
								particles.toSpawn ~= ParticleSpawner.Data(vec3(exhaustL.x, 0.5f,
										exhaustL.y), 1, ParticleInfo(vec4(1, 1, 1, 1), 4, -0.5f,
										vec3(physics.linearVelocity.x, 0, physics.linearVelocity.y) * 0.25f, 0.5f));
								particles.toSpawn ~= ParticleSpawner.Data(vec3(exhaustR.x, 0.5f,
										exhaustR.y), 1, ParticleInfo(vec4(1, 1, 1, 1), 4, -0.5f,
										vec3(physics.linearVelocity.x, 0, physics.linearVelocity.y) * 0.25f, 0.5f));
								if (Keyboard.state.isKeyPressed(controls.boost))
								{
									particles.toSpawn ~= ParticleSpawner.Data(vec3(exhaustL2.x,
											0.5f, exhaustL2.y), 1, ParticleInfo(vec4(1, 0.5f, 0.5f,
											1), 4, -0.5f, vec3(physics.linearVelocity.x, 0,
											physics.linearVelocity.y) * 0.5f, 0.5f));
									particles.toSpawn ~= ParticleSpawner.Data(vec3(exhaustR2.x,
											0.5f, exhaustR2.y), 1, ParticleInfo(vec4(1, 0.5f, 0.5f,
											1), 4, -0.5f, vec3(physics.linearVelocity.x, 0,
											physics.linearVelocity.y) * 0.5f, 0.5f));
								}
							}
						}
						if (Keyboard.state.isKeyPressed(controls.decelerate))
						{
							if (physics.linearVelocity.length_squared >= 2 * 2 && !physics.reversing)
								physics.linearVelocity *= pow(0.5, world.delta);
							else
							{
								physics.reversing = true;
								physics.linearVelocity -= vec2(sin(physics.rotation),
										-cos(physics.rotation)) * world.delta * (Keyboard.state.isKeyPressed(controls.boost)
										? 100 : 50);
							}
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

						foreach (other; world.entities)
						{
							if (other.alive)
							{
								TrackCollision* track;
								if (other.fetch(track))
								{
									foreach (i, a; track.innerRing)
									{
										auto b = track.innerRing[(i + 1) % $];
										auto nrm = (a - b).yx.normalized;
										nrm.y = -nrm.y;
										vec2 intersection;
										for (int repeat = 0; repeat < 10 && (lineLineIntersects(a, b, tl, tr, intersection)
												|| lineLineIntersects(a, b, tr, br, intersection) || lineLineIntersects(a, b, br, bl,
												intersection) || lineLineIntersects(a, b, bl, tl, intersection));
												repeat++)
										{
											if (repeat == 0)
											{
												if (canParticle)
													particles.toSpawn ~= ParticleSpawner.Data(vec3(intersection.x,
															0, intersection.y), 0, ParticleInfo(vec4(1, 1, 1,
															1), 4, 0, vec3(0, 10, 0), 0.8f));
												physics.linearVelocity *= 0.95f;
												physics.linearVelocity += nrm;
											}
											tl -= physics.position;
											tr -= physics.position;
											bl -= physics.position;
											br -= physics.position;
											physics.position += nrm * 0.05f;
											tl += physics.position;
											tr += physics.position;
											bl += physics.position;
											br += physics.position;
										}
									}
									foreach (i, b; track.outerRing)
									{
										auto a = track.outerRing[(i + 1) % $];
										auto nrm = (a - b).yx.normalized;
										nrm.y = -nrm.y;
										vec2 intersection;
										for (int repeat = 0; repeat < 10 && (lineLineIntersects(a, b, tl, tr, intersection)
												|| lineLineIntersects(a, b, tr, br, intersection) || lineLineIntersects(a, b, br, bl,
												intersection) || lineLineIntersects(a, b, bl, tl, intersection));
												repeat++)
										{
											if (repeat == 0)
											{
												if (canParticle)
													particles.toSpawn ~= ParticleSpawner.Data(vec3(intersection.x,
															0, intersection.y), 0, ParticleInfo(vec4(1, 1, 1,
															1), 4, -1, vec3(0, 10, 0), 0.5f));
												physics.linearVelocity *= 0.95f;
												physics.linearVelocity += nrm;
											}
											tl -= physics.position;
											tr -= physics.position;
											bl -= physics.position;
											br -= physics.position;
											physics.position += nrm * 0.05f;
											tl += physics.position;
											tr += physics.position;
											bl += physics.position;
											br += physics.position;
										}
									}
								}
							}
						}

						physics.cameraRotation = (physics.cameraRotation - physics.rotation) * pow(0.2,
								world.delta) + physics.rotation;
						transform.transform = mat4.translation(physics.position.x, 0,
								physics.position.y) * mat4.yrotation(-physics.rotation);
						renderer.modelview.top = mat4.xrotation(cradians!20) * mat4.translation(0,
								0, -15) * mat4.yrotation(physics.cameraRotation) * mat4.translation(-physics.position.x,
								-10, -physics.position.y);
						float speedFov = physics.linearVelocity.length * 0.3f;
						if (speedFov > 50)
							speedFov = 50;
						renderer.projection.top = perspective(window.width, window.height,
								40.0f + speedFov, 5.0f, 1000.0f);
					}
				}
			}
		}
	}

private:
	Renderer renderer;
	View window;
}
