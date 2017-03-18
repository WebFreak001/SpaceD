module app;

import avocado.assimp;
import avocado.bmfont;
import avocado.core;
import avocado.dfs;
import avocado.gl3;
import avocado.sdl2;

import scenemanager;
import scenes.ingame;
import scenes.mainmenu;
import scenes.leaderboard;
import shaderpool;

alias View = SDLWindow;
alias Renderer = GL3Renderer;
alias Shader = GL3ShaderProgram;
alias ShaderUnit = GLShaderUnit;
alias Texture = GLTexture;

alias Mesh = GL3MeshIndexPositionTextureNormal;
alias Font = BMFont!(Texture, ResourceManager);

Mesh convertAssimpMesh(AssimpMeshData from)
{
	auto mesh = new GL3MeshIndexPositionTextureNormal();
	mesh.primitiveType = PrimitiveType.Triangles;
	foreach (indices; from.indices)
		mesh.addIndexArray(indices);
	mesh.addPositionArray(from.vertices);
	if (from.texCoords.length)
	{
		foreach (texCoord; from.texCoords[0])
			mesh.addTexCoord(texCoord.xy);
	}
	else
	{
		foreach (vertex; from.vertices)
			mesh.addTexCoord(vertex.xy);
	}
	mesh.addNormalArray(from.normals);
	mesh.generate();
	return mesh;
}

void main()
{
	auto engine = new Engine;
	with (engine)
	{
		auto window = new View("Fluffy");
		auto renderer = new Renderer;
		window.setOpenGLVersion(3, 3);
		auto world = add(window, renderer);

		void onResized(int width, int height)
		{
			renderer.resize(width, height);
		}

		window.onResized ~= &onResized;
		onResized(window.width, window.height);

		auto resources = new ResourceManager();
		resources.prepend("res");
		resources.prependAll("packs", "*.{pack,zip}");

		renderer.setupDepthTest(DepthFunc.Less);

		SceneManager sceneManager = new SceneManager(world);

		ShaderPool shaders = new ShaderPool(resources);

		auto ingame = new IngameScene();
		ingame.load(sceneManager, renderer, window, resources, shaders);
		sceneManager.register(ingame, "ingame");

		auto leaderboards = new LeaderboardScene();
		leaderboards.load(sceneManager, renderer, window, resources, shaders);
		sceneManager.register(leaderboards, "leaderboards");

		auto mainmenu = new MainMenuScene();
		mainmenu.load(sceneManager, renderer, window, resources, shaders);
		sceneManager.register(mainmenu, "main");
		sceneManager.setScene("main");

		FPSLimiter limiter = new FPSLimiter(120);

		start();
		while (update)
			limiter.wait();
		stop();
	}
}
