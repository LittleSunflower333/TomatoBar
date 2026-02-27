<p align="center">
  <img src="https://raw.githubusercontent.com/ivoronin/TomatoBar/main/TomatoBar/Assets.xcassets/AppIcon.appiconset/icon_128x128%402x.png" width="128" height="128" alt="TomatoBar icon"/>
</p>

<h1 align="center">TomatoBar (Fork)</h1>

<p align="center">
  A macOS menu bar Pomodoro timer fork with a brand-new timer page and statistics page.
</p>

<p align="center">
  <a href="https://github.com/LittleSunflower333/TomatoBar/actions/workflows/main.yml">
    <img src="https://img.shields.io/github/actions/workflow/status/LittleSunflower333/TomatoBar/main.yml?branch=main" alt="Build Status"/>
  </a>
  <a href="https://github.com/LittleSunflower333/TomatoBar/releases">
    <img src="https://img.shields.io/github/v/release/LittleSunflower333/TomatoBar?display_name=tag" alt="Latest Release"/>
  </a>
  <a href="https://github.com/LittleSunflower333/TomatoBar/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/LittleSunflower333/TomatoBar" alt="License"/>
  </a>
</p>

## Fork Notice

This repository is a **fork** of [ivoronin/TomatoBar](https://github.com/ivoronin/TomatoBar).

- Upstream project: [ivoronin/TomatoBar](https://github.com/ivoronin/TomatoBar)
- This fork: [LittleSunflower333/TomatoBar](https://github.com/LittleSunflower333/TomatoBar)

## Overview

TomatoBar is a Pomodoro timer for the macOS menu bar with:

- Configurable work and rest intervals
- Optional sounds
- Actionable notifications
- Global shortcut support

The app is sandboxed and designed for lightweight daily use.

## What's New In This Fork

- Added a brand-new timer page with a centered circular countdown progress ring and tomato-based in-session progress markers.
- Added a brand-new statistics page with week/month views, heatmap and bar chart modes, hover-driven detail switching, and current day/period highlighting.

## Install

Build from source in Xcode:

1. Clone this repository.
2. Open `TomatoBar.xcodeproj`.
3. Select your signing team if needed.
4. Build and run.

Upstream Homebrew install remains available for the original project:

```bash
brew install --cask tomatobar
```

If the app does not start, try:

```bash
brew install --cask --no-quarantine tomatobar
```

## Integration

### Event Log

TomatoBar logs state transitions in JSON format to:

`~/Library/Containers/com.github.ivoronin.TomatoBar/Data/Library/Caches/TomatoBar.log`

### URL Scheme

Start/stop timer from terminal:

```bash
open tomatobar://startStop
```

## Credits

- Original author and upstream maintainers: [ivoronin/TomatoBar](https://github.com/ivoronin/TomatoBar)
- This fork keeps original attribution and builds on top of the upstream implementation.

## License

This fork is distributed under the [MIT License](LICENSE), consistent with the upstream project.

Third-party assets:

- Timer sounds are licensed from buddhabeats.
