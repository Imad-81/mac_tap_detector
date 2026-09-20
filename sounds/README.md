# Sounds Directory

This directory contains the audio files played whenever a physical tap or knock on your MacBook chassis is detected.

## Supported Formats

You can drop any standard macOS-supported audio format here:
* `.wav` (PCM 16-bit / 24-bit / 32-bit float)
* `.mp3`
* `.aiff` / `.aif`
* `.m4a` / `.aac`
* `.caf`

## Starter Sounds Included

The project automatically initializes starter sound effects:
* `bonk.wav` – Cartoon hollow wooden bonk with pitch glide
* `boing.wav` – Spring wobble cartoon boing
* `metal.wav` – Heavy metallic pipe clank
* `pop.wav` – Snappy woodblock pop
* `thud.wav` – Low frequency punchy impact

## Sound Modes

You can select sound modes with the `--mode` flag:

* `--mode random` (default): Randomly picks any audio file found in `sounds/`.
* `--mode bonk`: Filters for sounds containing "bonk", "thud", "metal", or "pipe" in the filename.
* `--mode meme`: Filters for sounds containing "meme", "vine", "bruh", or "boing".
* `--mode system`: Uses built-in macOS system sounds (`Ping`, `Pop`, `Funk`, `Hero`, `Tink`, etc.).

## Adding Custom Sounds

Simply copy any sound files (e.g. `vine_boom.mp3`, `metal_pipe.wav`, `oof.wav`) into this `sounds/` folder. The application automatically re-catalogs all files on startup.
