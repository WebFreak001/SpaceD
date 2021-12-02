module config;

import avocado.bmfont;
import avocado.dfs;
import avocado.gl3;
import avocado.sdl2;

alias View = SDLWindow;
alias Renderer = GL3Renderer;
alias ShaderUnit = GLShaderUnit;
alias Shader = GL3ShaderProgram;
alias Shape = GL3ShapePosition;
alias Texture = GLTexture;
alias Font = BMFont!(Texture, ResourceManager);
