# TurnInPlanner

`TurnInPlanner` is a Turtle WoW 1.12 addon for planning the cheapest way to complete repeatable turn-ins from Auction House data.

Current v1 scope:

- Darkmoon Faire ticket planning
- Real Auction House snapshot scanning
- Strategy switching:
  - Cheapest total cost
  - Prefer 20-ticket turn-ins
  - Prefer 1-ticket turn-ins
- Candidate ranking by current effective cost
- Optional `aux-addon` history fallback when not at the Auction House

## Features

- Scans current Auction House listings for Darkmoon turn-in items
- Accounts for limited supply and different stack prices
- Builds a purchase plan for a target ticket amount
- Shows a ranked list of currently efficient materials
- Works alongside `aux-addon`

## Requirements

- Turtle WoW 1.12 client
- Recommended: `aux-addon`

Without `aux-addon`, current Auction House scanning still works, but history-based estimation does not.

## Installation

1. Place the `TurnInPlanner` folder into your `Interface/AddOns` directory.
2. Restart the client or reload the UI.
3. Enable the addon from the addon list if needed.

## Usage

1. Type `/tip` or `/turnin` to open the addon window.
2. Open the Auction House.
3. Click `刷新当前拍卖`.
4. Choose a target and a strategy.
5. Review the recommended purchase plan and ranking list.

## Commands

- `/tip`
- `/turnin`

## Included Dataset

Current release includes:

- Darkmoon Faire

Planned future expansion:

- Ahn'Qiraj War Effort

## Project Structure

- `TurnInPlanner.toc`: addon manifest
- `TurnInPlanner.lua`: state, events, slash commands
- `datasets.lua`: dataset definitions
- `price.lua`: Auction House pricing model
- `solver.lua`: planning solver
- `scan.lua`: Auction House scanning
- `ui.lua`: in-game UI
- `localization.cn.lua`: Chinese localization

## Notes

- Auction House mode uses only the current live scan snapshot.
- History fallback is used only outside the Auction House.
- Results reflect buyout-based purchasing, not bidding.

## License

MIT
