module audio;

import avocado.core;
import avocado.sdl2;

import derelict.sdl2.mixer;

import std.conv;
import std.string;

import globstate;

class Audio : IResourceProvider
{
	immutable(ubyte)[] data;
	SDL_RWops* rw;
	Mix_Chunk* sample;

	~this()
	{
		Mix_FreeChunk(sample);
		SDL_FreeRW(rw);
	}

	/// Unused
	void error()
	{
	}
	/// Unused
	@property string errorInfo()
	{
		return Mix_GetError().fromStringz.idup;
	}

	bool load(ref ubyte[] stream)
	{
		data = stream.idup;
		rw = SDL_RWFromConstMem(cast(const(ubyte)*) data.ptr, cast(int) data.length);
		sample = Mix_LoadWAV_RW(rw, 0);
		return !!sample;
	}

	/// True for .wav files
	bool canRead(string extension)
	{
		return extension == ".wav";
	}

	void play(int loops = 0, int channel = -1, ubyte volume = MIX_MAX_VOLUME)
	{
		if (settings.disableSound)
			return;
		Mix_Volume(channel, volume);
		Mix_PlayChannel(channel, sample, loops);
	}
}
