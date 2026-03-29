# cliamp-plugin-soap-bubbles

A visualizer plugin for [cliamp](https://github.com/bjarneo/cliamp) that renders floating soap bubbles using Braille dot characters. Bubbles drift upward, pulse with bass, wobble with treble, and shimmer as they float.

## Install

```sh
cliamp plugins install bjarneo/cliamp-plugin-soap-bubbles
```

Or manually:

```sh
cp soap-bubbles.lua ~/.config/cliamp/plugins/
```

## Usage

Start cliamp and press `v` to cycle through visualizers until you reach **soap-bubbles**.

## How it works

- 14 hollow bubbles drawn with Braille dots (2x4 pixels per character cell)
- Each bubble is driven by one of the 10 frequency bands
- Bass inflates the radius, treble adds wobble
- Specular highlight arc near the top-left for the soap look
- Bubbles rise faster when the music is louder
- Wraps around when exiting the top or sides

## Uninstall

```sh
cliamp plugins remove soap-bubbles
```

## License

MIT
