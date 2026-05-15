# stock-value

DFHack overlay for Dwarf Fortress 53.12 that displays exact item values inline on the vanilla Stocks screen.

## Requirements

- Dwarf Fortress 53.12
- DFHack 53.12-r1 or compatible

## Install

Copy the script into your DFHack scripts directory:

```sh
cp hack/scripts/stock-value.lua /path/to/df/hack/scripts/stock-value.lua
```

In the DFHack console:

```lua
lua "require('plugins.overlay').rescan()"
overlay enable stock-value.values
```

## Use

Open the vanilla Stocks screen. Expanded item rows show their exact item value in yellow near the row action buttons.

Group/header rows are intentionally skipped.
