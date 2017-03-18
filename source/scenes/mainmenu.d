module scenes.mainmenu;

import avocado.assimp;
import avocado.core;
import avocado.dfs;
import avocado.gl3;
import avocado.sdl2;

import app;
import components;
import scenemanager;
import systems.menu;
import trackgen;
import shaderpool;

class MainMenuScene : IScene
{
	override void load(SceneManager sceneManager, Renderer renderer, View window, ResourceManager resources, ShaderPool shaders)
	{
		auto textVert = shaders.load(ShaderType.Vertex, "shaders/text.vert");
		auto textureFrag = shaders.load(ShaderType.Fragment, "shaders/texture.frag");

		Shader textShader = new Shader(renderer, textVert, textureFrag);
		Font font = resources.load!Font("fonts/roboto.fnt", resources, "fonts/");

		world.addSystem!MenuSystem(renderer, window, font, textShader, sceneManager);

		mixin(createEntity!("Play Button", q{
			Button: "Play"d, vec4(0.5f, 0.5f, 0.5f, 1), vec4(1), vec4(10, 10, 100, 50)
			TabFocus: 0
			SceneSwitchAction: "ingame"
		}));
		mixin(createEntity!("Exit Button", q{
			Button: "Exit"d, vec4(0.5f, 0.5f, 0.5f, 1), vec4(1), vec4(10, 60, 100, 50)
			TabFocus: 1
			SceneSwitchAction: "crash"
		}));
	}

	override void preEnter(IScene prev)
	{
	}

	override void postExit(IScene next)
	{
	}
}
