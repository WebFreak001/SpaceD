module systems.menu;

import avocado.core;
import avocado.gl3;
import avocado.sdl2;
import avocado.dfs;
import avocado.input;

import app;
import text;
import globstate;
import components;
import scenemanager;
import particles;

import std.algorithm;
import std.conv;
import std.stdio;

class MenuSystem : ISystem
{
public:
	this(Renderer renderer, View window, Font font, Shader textShader, SceneManager sceneManager)
	{
		this.renderer = renderer;
		this.window = window;
		this.sceneManager = sceneManager;
		text = new Text(font, textShader);
	}

	final void update(World world)
	{
		renderer.begin(window);
		renderer.clear();
		renderer.bind2D();
		renderer.modelview.push();
		renderer.modelview = mat4.identity;

		int maxTabIndex = 0;

		foreach (entity; world.entities)
		{
			if (entity.alive)
			{
				{
					Button* button;
					if (entity.fetch(button))
					{
						bool focused;
						bool act;
						if (Mouse.state.x > button.rect.x
								&& Mouse.state.x <= button.rect.x + button.rect.z
								&& Mouse.state.y > button.rect.y && Mouse.state.y <= button.rect.y + button.rect.a)
						{
							focused = true;
							if (!Mouse.state.isButtonPressed(1) && prevMouse.isButtonPressed(1))
								act = true;
						}
						TabFocus tabFocus;
						if (entity.fetch(tabFocus))
						{
							if (tabFocus.index > maxTabIndex)
								maxTabIndex = tabFocus.index;
							if (curTabIndex == tabFocus.index)
							{
								focused = true;
								if (!Keyboard.state.isKeyPressed(Key.Return)
										&& prevKeyboard.isKeyPressed(Key.Return))
									act = true;
							}
						}
						if (focused)
							renderer.fillRectangle(button.rect, (button.bg + vec4(0, 0, 1, 1)) * 0.5f);
						else
							renderer.fillRectangle(button.rect, button.bg);
						if (act)
						{
							BuyAction buyAction;
							if (entity.fetch(buyAction))
							{
								int cost = globalState.upgradeCost(buyAction.upgradeIndex);
								if (globalState.money >= cost)
								{
									globalState.binUpgrades[buyAction.upgradeIndex]++;
									globalState.money -= cost;
								}
							}
							SceneSwitchAction sceneAction;
							if (entity.fetch(sceneAction))
								sceneManager.setScene(sceneAction.scene);
						}
						text.text = button.text;
						renderer.modelview.push();
						renderer.modelview.top *= mat4.translation(
								vec3(button.rect.x + (button.rect.z - text.textWidth * 768) * 0.5,
								button.rect.y + text.lineHeight * 512 + (button.rect.a - text.lineHeight * 512) * 0.5,
								0)) * mat4.scaling(768, 512, 1);
						text.draw(renderer);
						renderer.modelview.pop();
					}
				}
				{
					GUIText* guitext;
					if (entity.fetch(guitext))
					{
						text.text = guitext.text;
						renderer.modelview.push();
						renderer.modelview.top *= mat4.translation(vec3(guitext.pos.x,
								guitext.pos.y, 0)) * mat4.scaling(768 * guitext.scale.x, 512 * guitext.scale.y, 1);
						text.draw(renderer);
						renderer.modelview.pop();
					}
				}
			}
		}

		if ((Keyboard.state.isKeyPressed(Key.Tab)
				&& !prevKeyboard.isKeyPressed(Key.Tab))
				|| (Keyboard.state.isKeyPressed(Key.Down) && !prevKeyboard.isKeyPressed(Key.Down)))
			curTabIndex = (curTabIndex + 1) % (maxTabIndex + 1);
		if (Keyboard.state.isKeyPressed(Key.Up) && !prevKeyboard.isKeyPressed(Key.Up))
			curTabIndex = (curTabIndex + maxTabIndex) % (maxTabIndex + 1);

		prevMouse = (*Mouse.state);
		prevKeyboard = KeyboardState(Keyboard.state.keys.dup);

		renderer.modelview.pop();
		renderer.bind3D();
		renderer.end(window);
	}

private:
	SceneManager sceneManager;
	Renderer renderer;
	View window;
	Text text;
	int curTabIndex;

	MouseState prevMouse;
	KeyboardState prevKeyboard;
}
