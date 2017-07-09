module audio;

import avocado.core;
import avocado.sdl2;

import derelict.sdl2.mixer;

import std.conv;
import std.string;
import std.datetime;

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

class Music : IResourceProvider
{
	immutable(ubyte)[] data;
	SDL_RWops* rw;
	Mix_Music* music;
	StopWatch position;
	string name;

	this(string name)
	{
		this.name = name;
	}

	~this()
	{
		Mix_FreeMusic(music);
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
		music = Mix_LoadMUS_RW(rw, 0);
		return !!music;
	}

	/// True for .wav files
	bool canRead(string extension)
	{
		return extension == ".wav" || extension == ".ogg";
	}

	void play(int loops = -1)
	{
		if (settings.disableMusic)
			return;
		Mix_PlayMusic(music, loops);
		position.start();
	}

	void stop()
	{
		Mix_HaltMusic();
		position.stop();
	}

	void fadeOut(int ms)
	{
		Mix_FadeOutMusic(ms);
		position.stop();
	}

	void fadeIn(int ms, int loops = -1)
	{
		if (settings.disableMusic)
			return;
		Mix_FadeInMusicPos(music, loops, ms, position.peek.to!("seconds", double));
		position.start();
	}
}

__gshared bool musicFinished = true;

extern (C) void musicFinishedHandler() @nogc nothrow
{
	musicFinished = true;
}

class MusicPlayer
{
	Music[] tracks;
	size_t currentTrack;
	bool playing = true;

	this()
	{
		Mix_HookMusicFinished(&musicFinishedHandler);
	}

	void play()
	{
		if (settings.disableMusic || tracks.length == 0)
			return;
		tracks[currentTrack].fadeIn(500);
		playing = true;
	}

	void stop()
	{
		playing = false;
		if (tracks.length == 0)
			return;
		tracks[currentTrack].fadeOut(500);
	}

	bool update()
	{
		if (musicFinished)
		{
			musicFinished = false;
			if (playing && tracks.length)
			{
				tracks[currentTrack].stop();
				currentTrack = (currentTrack + 1) % tracks.length;
				tracks[currentTrack].play(0);
				return true;
			}
		}
		return false;
	}

	void shuffle()
	{
		import std.random : randomShuffle;

		tracks.randomShuffle();
	}
}
