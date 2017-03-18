module shaderpool;

import avocado.core;
import avocado.dfs;
import avocado.gl3;

import app;

class ShaderPool
{
public:
	this(ResourceManager res)
	{
		resources = res;
	}

	ShaderUnit load(ShaderType type, string file)
	{
		auto shaderPtr = file in shaders;
		if (shaderPtr)
			return *shaderPtr;
		return shaders[file] = new ShaderUnit(type, resources.load!TextProvider(file).value);
	}

private:
	ShaderUnit[string] shaders;
	ResourceManager resources;
}
