module systems.logic;

import avocado.core;
import avocado.input;
import avocado.sdl2;

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

private bool playerPlayerIntersects(vec2[4] a, vec2[4] b, ref vec2 i)
{
	if ((a[0] - b[0]).length_squared > 10 * 10)
		return false;
	//dfmt off
	return lineLineIntersects(a[0], a[1], b[0], b[1], i)
		|| lineLineIntersects(a[0], a[1], b[1], b[2], i)
		|| lineLineIntersects(a[0], a[1], b[2], b[3], i)
		|| lineLineIntersects(a[0], a[1], b[3], b[0], i)
		|| lineLineIntersects(a[1], a[2], b[0], b[1], i)
		|| lineLineIntersects(a[1], a[2], b[1], b[2], i)
		|| lineLineIntersects(a[1], a[2], b[2], b[3], i)
		|| lineLineIntersects(a[1], a[2], b[3], b[0], i)
		|| lineLineIntersects(a[2], a[3], b[0], b[1], i)
		|| lineLineIntersects(a[2], a[3], b[1], b[2], i)
		|| lineLineIntersects(a[2], a[3], b[2], b[3], i)
		|| lineLineIntersects(a[2], a[3], b[3], b[0], i)
		|| lineLineIntersects(a[3], a[0], b[0], b[1], i)
		|| lineLineIntersects(a[3], a[0], b[1], b[2], i)
		|| lineLineIntersects(a[3], a[0], b[2], b[3], i)
		|| lineLineIntersects(a[3], a[0], b[3], b[0], i);
	//dfmt on
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
					VehicleAI* ai;
					if (entity.fetch(transform, physics))
					{
						auto corners = physics.generateCornersAndExhaust;
						bool canParticle;
						if (!entity.fetch(particles))
							canParticle = false;
						else
						{
							particles.time += world.delta;
							if (particles.time >= 0.005f)
							{
								canParticle = true;
								particles.time = 0;
							}
						}
						float acceleration = 0;
						bool shouldBoost;
						bool shouldDecelerate;
						float steering = 0;
						bool hasControls = entity.fetch(controls);
						if (hasControls)
						{
							if (Keyboard.state.isKeyPressed(controls.accelerate))
								acceleration = 1;
							if (Keyboard.state.isKeyPressed(controls.boost))
								shouldBoost = true;
							if (Keyboard.state.isKeyPressed(controls.decelerate))
								shouldDecelerate = true;
							if (Keyboard.state.isKeyPressed(controls.steerLeft))
								steering = -1;
							if (Keyboard.state.isKeyPressed(controls.steerRight))
								steering = 1;
						}
						else if (entity.fetch(ai))
						{
							if (ai.nextWaypoint.isFinite)
							{
								if ((ai.nextWaypoint - physics.position).length_squared < 50 * 50)
									ai.nextWaypoint = vec2(float.nan);
								else
								{
									float s = sin(physics.rotation);
									float c = cos(physics.rotation);
									float f = (ai.nextWaypoint - physics.position).normalized.dot(vec2(c, s));
									acceleration = 1.5f; // AI can cheat a bit, it's too easy otherwise
									float strength = abs(f) < 0.2f ? 0.5f : 1.0f;
									if (strength < 0.75f)
										shouldBoost = true;
									if (f < 0)
										steering = -strength;
									else
										steering = strength;
								}
							}
						}
						physics.angularVelocity += world.delta * 3 * steering;

						if (acceleration > 0)
						{
							physics.linearVelocity += vec2(sin(physics.rotation),
									-cos(physics.rotation)) * world.delta * (shouldBoost ? 50 : 25) * acceleration;
							physics.reversing = false;

							if (canParticle)
							{
								particles.toSpawn ~= ParticleSpawner.Data(vec3(corners[4].x,
										0.5f, corners[4].y), 1, ParticleInfo(vec4(1, 1, 1, 1), 4,
										-0.5f, vec3(physics.linearVelocity.x, 0,
										physics.linearVelocity.y) * 0.25f, 0.5f));
								particles.toSpawn ~= ParticleSpawner.Data(vec3(corners[5].x,
										0.5f, corners[5].y), 1, ParticleInfo(vec4(1, 1, 1, 1), 4,
										-0.5f, vec3(physics.linearVelocity.x, 0,
										physics.linearVelocity.y) * 0.25f, 0.5f));
								if (shouldBoost)
								{
									particles.toSpawn ~= ParticleSpawner.Data(vec3(corners[6].x,
											0.5f, corners[6].y), 1, ParticleInfo(vec4(1, 0.5f, 0.5f,
											1), 4, -0.5f, vec3(physics.linearVelocity.x, 0,
											physics.linearVelocity.y) * 0.5f, 0.5f));
									particles.toSpawn ~= ParticleSpawner.Data(vec3(corners[7].x,
											0.5f, corners[7].y), 1, ParticleInfo(vec4(1, 0.5f, 0.5f,
											1), 4, -0.5f, vec3(physics.linearVelocity.x, 0,
											physics.linearVelocity.y) * 0.5f, 0.5f));
								}
							}
						}
						if (shouldDecelerate)
						{
							if (physics.linearVelocity.length_squared >= 2 * 2 && !physics.reversing)
								physics.linearVelocity *= pow(0.5, world.delta);
							else
							{
								physics.reversing = true;
								physics.linearVelocity -= vec2(sin(physics.rotation),
										-cos(physics.rotation)) * world.delta * (Keyboard.state.isKeyPressed(controls.boost)
										? 50 : 25);
							}
						}

						if (physics.angularVelocity < -1.5f)
							physics.angularVelocity = -1.5f;
						if (physics.angularVelocity > 1.5f)
							physics.angularVelocity = 1.5f;
						physics.angularVelocity *= pow(0.4, world.delta);
						physics.linearVelocity *= pow(0.8, world.delta);
						physics.rotation += physics.angularVelocity * world.delta;
						physics.position += physics.linearVelocity * world.delta;

						bool checkRingCollision(vec2 a, vec2 b)
						{
							auto nrm = (a - b).yx.normalized;
							nrm.y = -nrm.y;
							vec2 intersection;
							bool ret;
							for (int repeat = 0; repeat < 10 && (lineLineIntersects(a, b, corners[0],
									corners[1], intersection) || lineLineIntersects(a, b, corners[1], corners[3],
									intersection) || lineLineIntersects(a, b, corners[3], corners[2],
									intersection) || lineLineIntersects(a, b, corners[2], corners[0], intersection));
									repeat++)
							{
								if (repeat == 0)
								{
									ret = true;
									if (canParticle)
										particles.toSpawn ~= ParticleSpawner.Data(vec3(intersection.x,
												0, intersection.y), 0, ParticleInfo(vec4(1, 1, 1, 1),
												4, 0, vec3(physics.linearVelocity.x * 0.03f, 10,
												physics.linearVelocity.y * 0.03f), 0.8f));
									physics.linearVelocity *= 0.95f;
									physics.linearVelocity += nrm;
								}
								corners[0 .. 4] -= physics.position;
								physics.position += nrm * 0.05f;
								corners[0 .. 4] += physics.position;
							}
							return ret;
						}

						foreach (other; world.entities)
						{
							if (other.alive && other != entity)
							{
								TrackCollision* track;
								if (other.fetch(track))
								{
									if (ai && !ai.nextWaypoint.isFinite)
									{
										ai.trackIndex = (ai.trackIndex + 2) % track.innerRing.length;
										ai.nextWaypoint = (
												track.innerRing[ai.trackIndex] * 3 + track.outerRing[ai.trackIndex]) * 0.25f;
									}
									foreach (i, a; track.innerRing)
										checkRingCollision(a, track.innerRing[(i + 1) % $]);
									foreach (i, b; track.outerRing)
										checkRingCollision(track.outerRing[(i + 1) % $], b);
								}
								VehiclePhysics* otherCar;
								if (other.fetch(otherCar))
								{
									auto otherCorners = otherCar.generateCornersAndExhaust;
									vec2 nrm = physics.position - otherCar.position;
									nrm.normalize;
									vec2 intersection;
									for (int repeat = 0; repeat < 4 && playerPlayerIntersects(corners[0 .. 4],
											otherCorners[0 .. 4], intersection); repeat++)
									{
										if (repeat == 0)
										{
											if (canParticle)
												particles.toSpawn ~= ParticleSpawner.Data(vec3(intersection.x,
														0, intersection.y), 0, ParticleInfo(vec4(1, 1, 1, 1),
														4, 0, vec3(physics.linearVelocity.x * 0.03f, 10,
														physics.linearVelocity.y * 0.03f), 0.8f));
											physics.linearVelocity *= 0.95f;
											otherCar.linearVelocity *= 0.95f;
											physics.linearVelocity += nrm;
											otherCar.linearVelocity -= nrm;
										}
										physics.position += nrm * 0.025f;
										otherCar.position -= nrm * 0.025f;
									}
								}
							}
						}

						physics.cameraRotation = (physics.cameraRotation - physics.rotation) * pow(0.2,
								world.delta) + physics.rotation;
						transform.transform = mat4.translation(physics.position.x, 0,
								physics.position.y) * mat4.yrotation(-physics.rotation);
						if (hasControls)
						{
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
	}

private:
	Renderer renderer;
	View window;
}
