module scenemanager;

import avocado.core;
import avocado.dfs;

import app;
import shaderpool;

abstract class IScene
{
	this()
	{
		this.world = new World();
	}

	abstract void load(SceneManager sceneManager, Renderer renderer, View window, ResourceManager resources, ShaderPool shaders);
	abstract void preEnter(IScene prev);
	abstract void postExit(IScene next);

	public World world;
}

final class SceneManager
{
	this(World world)
	{
		this.world = world;
	}

	void register(IScene scene, string name)
	{
		scenes[name] = scene;
	}

	void setScene(string name)
	{
		auto sceneP = name in scenes;
		if (!sceneP)
			throw new Exception("Scene not found");
		auto scene = *sceneP;
		scene.preEnter(curScene);
		world.systems = scene.world.systems;
		world.entities = scene.world.entities;
		if (curScene)
			curScene.postExit(scene);
		curScene = scene;
	}

private:
	World world;
	IScene curScene;
	IScene[string] scenes;
}
