# Procedural Terrain Generation

What happens when you've got nowhere to go and nothing to do for Thanksgiving break with a big scary project due in a few weeks? That's *exactly* what this is! :sweat_smile:

## Table of Contents

- [Description](#description)
  - [Motivation](#motivation)
- [Installation](#installation)
  - [General](#generally-for-general-people)
  - [Modding](#complicatedly-for-nerds)
- [Usage](#usage)
  - [Controls](#controls)
  - [Biome Painting](#biome-painting)
  - [For Modders](#for-modders)
- [How to Contribute](#how-to-contribute)
- [License](#license)

## Description

### Motivation

Just to clear the air, yes this is a class project. The class was CS334 Fundamentals of Computer Graphics. The assignment was to extend what we learned throughout the semester to a project of our interest. We were given a choice of few "projects in a can" or our own project. I chose a canned project, the assignment for which is as follows:

> #### Procedural Modeling
> Develop a system of modeling for procedurally modeling 3D plants, buildings, roads, cities, or terrain. Terrain should be realistic-looking, including white snow for high areas and blue water for low areas. The model should not be hardcoded.

We were given a month and that's pretty much it. I decided to take it much further than the assignment asked, and I hope that shows here.

## Installation

It would be helpful to know how to use this project, huh?

### Generally, For General People

If you are looking to just try the thing, all you need to do is go to the [GitHub page](https://github.com/Lion4567714/prodecural_terrain_generation), navigate to the Releases tab on the right, and click the one with the highest number. You're looking for something called `procedural_terrain_generator.exe`. Download that and run it, voilà!

> [!NOTE]
> I'd be surprised if your computer didn't warn you against running suspicious executables from random people on the internet. While I promise this isn't malware, please be aware of your internet safety practices.

### Complicatedly, For Nerds

If you're looking to get a little more into it and you want to play around with the code, I got you covered.

You'll need Godot Engine. I used Godot 4.2. You can probably get away with using newer versions of Godot, but no guarantees it works anymore! :smile: 

Next, clone the repository. Click the big green `<>Code` button towards and top, then click `Download Zip`. Unzip that. Now you have the source code!

Then, open the folder as a new project with Godot Engine. Now you can play around with the game just as I can. It should be as easy as that!

## Usage

Okay, it opened. How do I use it?

### Controls

- Movement Controls
  - `Mouse` - Look around
  - `W` - Move forward
  - `S` - Move backward
  - `A` - Move left
  - `D` - Move right
  - `C` - Move up
  - `Space` - Move down
- Biome Controls
  - `Scroll` - Select Biome
  - `Up/Down` - Select Brush Size
  - `Left Click` - Paint Biome
- Terrain Controls
  - `E` - Erase terrain
  - `R` - Regenerate terrain
  - `B` - Toggle biome map
  - `H` - Toggle height map
  - `O` - Toggle terrain smoothing
  - `F` - Toggle feature map
- Debug Controls
  - `M` - Toggle status messages
  - `T` - Toggle biome test

### Biome Painting

At the start, you are given a blank canvas for you to draw upon. Feel free to draw to your heart's content.

> [!CAUTION]
> Refrain from letting your painted biomes touch (i.e. leave a little white in between). In some cases, this will crash the game. This will be fixed soon.

Press `R` to generate your terrain, and the changes you made in the canvas will reflect in the terrain!

### For Modders

For those of you who want to modify the game files to quickly change some game settings, this is for you.

Most of the interesting stuff is going on in `mesh_controller.gd`. Feel free to play around with the mesh settings at the top and see how they affect your terrain.

If you want to add your own custom biomes, you can do so in the `initialize_biomes()` function. 

## How to Contribute

If you are interested in getting involved and helping me out with this project, feel free to fork this repository or start an issue on GitHub. I'm happy to respond to any suggestions or issues that come up.

You can also reach out to me [via email](mailto:ablion@ablion.dev)

## License

MIT License (c) 2024 Anders Gilliland