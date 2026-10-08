# ballest-plugins

Plugins for the [Ballest plugin manager](https://github.com/AnythingGoes-ballest/ballest-plugin-manager), for
Ballest of Them All. Each plugin is a folder under `plugins/`, versioned on its own with tags named
`<plugin id>-v<version>` (for example `grind-stats-v0.1.0`).

- **Checkpoint Finder** (`plugins/checkpoint-finder`): marks every checkpoint of the map you're on, through walls,
  and greys out the ones you've touched this run. Private for now, not in the registry.

Grind Stats, which started here, now lives in
[AnythingGoes-ballest/ballest-grind-stats](https://github.com/AnythingGoes-ballest/ballest-grind-stats) as its 0.2.0.
The registry can list a plugin straight from this repo with `--path plugins/<id>`.

## Trying a plugin before it's in the registry

Copy its folder into the game's `Binaries\Win64\plugins\` folder (the plugin manager must be installed) and start
the game.

## License

MIT (see [LICENSE](LICENSE)).
