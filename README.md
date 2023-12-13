# FS22_BetterCoverCrops

## Mod description

This mod strives to allow the player to respect the three [Conservation Agriculture](https://www.fao.org/conservation-agriculture/en/) principles.
Read the description in the [mod desc xml](modDesc.xml) for more information.

## How to install

1. Download the newest zip from the [Releases page](https://github.com/Timmeey86/FS22_ConservationAgriculture/releases)
1. Place the zip file in your FS22 mod folder
1. Start the game and use like any other mod

## Implemented Features

- Cover Crops and Forageable crops can be mulched or rolled over, in which case they will be mulched and will apply the maximum possible fertilization on the field. (rolling cuts the fruit but does not add a mulch layer yet)

## Planned features

- Add a mulch layer when rolling
- Change the ground visuals to a mulched ground when rolling
- Add one level of fertilizer instead of maxing out since slurry + cover crop is probably more realistic
- Support precision farming

## How to debug/code

1. Obviously, own a copy of Farming Simulator 22
1. Clone this folder anywhere
1. Use Visual Code with at least the Lua Language Server Plugin for coding
1. When testing, execute copytofs.bat and open that mod folder in Giants Studio
1. Debug in Giants Studio