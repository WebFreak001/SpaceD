module scenes.mainmenu;

import avocado.assimp;
import avocado.core;
import avocado.dfs;
import avocado.gl3;
import avocado.sdl2;

import app;
import components;
import globstate;
import scenemanager;
import shaderpool;
import systems.menu;
import trackgen;

import std.conv;

class MainMenuScene : IScene
{
	override void load(SceneManager sceneManager, Renderer renderer, View window,
			ResourceManager resources, ShaderPool shaders)
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
		mixin(createEntity!("Shop Button", q{
			Button: "Shop"d, vec4(0.5f, 0.5f, 0.5f, 1), vec4(1), vec4(10, 70, 100, 50)
			TabFocus: 1
			SceneSwitchAction: "shop"
		}));
		mixin(createEntity!("Exit Button", q{
			Button: "Exit"d, vec4(0.5f, 0.5f, 0.5f, 1), vec4(1), vec4(10, 130, 100, 50)
			TabFocus: 2
			SceneSwitchAction: "crash"
		}));
		moneyCounter = mixin(createEntity!("Money Counter", q{
			GUIText: "Money: 0ĸ"d, vec2(300, 50), vec2(1, 1)
		}, "world", true));
	}

	override void preEnter(IScene prev)
	{
		moneyCounter.get!GUIText.text = "Money: "d ~ globalState.money.to!dstring ~ 'ĸ';
	}

	override void postExit(IScene next)
	{
	}

	Entity moneyCounter;
}

class ShopScene : IScene
{
	override void load(SceneManager sceneManager, Renderer renderer, View window,
			ResourceManager resources, ShaderPool shaders)
	{
		auto textVert = shaders.load(ShaderType.Vertex, "shaders/text.vert");
		auto textureFrag = shaders.load(ShaderType.Fragment, "shaders/texture.frag");

		Shader textShader = new Shader(renderer, textVert, textureFrag);
		Font font = resources.load!Font("fonts/roboto.fnt", resources, "fonts/");

		world.addSystem!MenuSystem(renderer, window, font, textShader, sceneManager);

		boostBuy = mixin(createEntity!("Buy Boost Button", q{
			Button: "Buy Boost"d, vec4(0.5f, 0.5f, 0.5f, 1), vec4(1), vec4(10, 10, 300, 50)
			TabFocus: 0
			BuyAction: 0
			SceneSwitchAction: "shop"
		}, "world", true));
		controlBuy = mixin(createEntity!("Control+ Button", q{
			Button: "+Air Resistance"d, vec4(0.5f, 0.5f, 0.5f, 1), vec4(1), vec4(10, 70, 300, 50)
			TabFocus: 1
			BuyAction: 1
			SceneSwitchAction: "shop"
		}, "world", true));
		mixin(createEntity!("Back Button", q{
			Button: "Back"d, vec4(0.5f, 0.5f, 0.5f, 1), vec4(1), vec4(10, 190, 300, 50)
			TabFocus: 2
			SceneSwitchAction: "main"
		}));
		boostUpgrades = mixin(createEntity!("Boost Counter", q{
			GUIText: "x0"d, vec2(350, 50), vec2(1, 1)
		}, "world", true));
		controlUpgrades = mixin(createEntity!("Control+ Counter", q{
			GUIText: "x0"d, vec2(350, 110), vec2(1, 1)
		}, "world", true));
		moneyCounter = mixin(createEntity!("Money Counter", q{
			GUIText: "Money: 0ĸ"d, vec2(10, 300), vec2(1, 1)
		}, "world", true));
	}

	override void preEnter(IScene prev)
	{
		updateMoney();
	}

	override void postExit(IScene next)
	{
		globalState.save();
	}

	void updateMoney()
	{
		moneyCounter.get!GUIText.text = "Money: "d ~ globalState.money.to!dstring ~ 'ĸ';
		boostBuy.get!Button.text = "Buy Boost ("d ~ globalState.upgradeCost(0).to!dstring ~ "ĸ)"d;
		controlBuy.get!Button.text = "+Air Resistance ("d ~ globalState.upgradeCost(1).to!dstring ~ "ĸ)"d;
		boostUpgrades.get!GUIText.text = 'x' ~ globalState.upgrades.boostLevel.to!dstring;
		controlUpgrades.get!GUIText.text = 'x' ~ globalState.upgrades.betterControls.to!dstring;
	}

	Entity boostBuy, controlBuy;
	Entity boostUpgrades, controlUpgrades;
	Entity moneyCounter;
}
