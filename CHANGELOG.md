# Changelog

All notable changes to Multi-Docks. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [2.3.2] - 2026-11-08

### Fixed

- Dock icons now try matching files in standard icon directories and AdwaitaLegacy when
  the active icon theme does not provide them. Apps without a usable image keep a visible
  letter tile instead of a blank slot.

## [2.3.1] - 2026-11-08

### Fixed

- Theme gradients now read Omarchy's named palette keys as well as indexed `color1` keys,
  so themes such as Spectral use their full set of colors instead of accent shades.

## [2.3.0] - 2026-11-08

### Added

- **Theme colors** for the gradient fill. *Gradient into* now also has *Next theme color*
  and *Theme colors*, which runs the dock through all the colors of your Omarchy theme (up
  to twelve, in the theme's order), not only the accent. It follows the theme as it changes.
- **Fade into** for gradient lines: a lighter shade (as before), the accent, the next
  theme color, or all the theme's colors. With theme colors the accents drawn with the
  lines (rails, brackets and the ornaments in the accent) run through them too.

### Changed

- New docks now start with the active Omarchy theme's full color spectrum on the fill and
  lines. They update when you choose another theme; existing color choices stay editable.
- With Custom or Monochrome colors there are no theme colors to use, so the gradient runs
  through shades of the accent instead, and a Monochrome dock stays without a hue.

## [2.2.0] - 2026-11-05

### Added

- **Icon scale** (Place): the icons bigger or smaller inside the dock, without changing
  the dock. They stop growing at its outline.
- A logo, in the settings header too, and an **About** tab with the version and a link
  to more plugins.

### Changed

- An app that is uninstalled leaves the docks by itself, a little after its desktop
  entry is gone, instead of staying as a blank icon.

### Fixed

- Reserve space with auto-hide: the windows make room again when the dock shows, and
  take the space back when it hides. The space only changed when something else made
  the shell redraw, so it was often left behind or never came.
- On Omarchy 4.5 the bar wasn't found, as its window now spans the screen. Docks on
  the side edges started at the very top, over the bar. The bar now comes from the
  shell, on every screen, and the docks follow it as it moves, hides or comes back.
- A wide panel on an edge, like the notifications, was taken for a bar, and docks on
  that edge stood that far in from it.
- In the settings preview, the fades at the ends of a long dock covered the dock's
  own ends and its outline.
- Warnings in the shell log while a dock's icons were being made, and while a removed
  dock was going away.

## [2.1.0] - 2026-10-17

### Added

- The new design settings, with a picture tile for every option and a preview drawn
  like the dock.

## [2.0.3] - 2026-10-16

### Fixed

- A stale bottom exclusive zone after a shell restart. No dock is made until the config
  is read, and the reserve spacers stay in Normal exclusion mode.

## [2.0.2] - 2026-10-15

### Changed

- The README and the code comments are rewritten, and the config is saved and read more
  carefully.

## [2.0.1] - 2026-10-15

### Changed

- The QML is organised into dock, settings and js folders, and the preview image is new.

## [2.0.0] - 2026-10-13

### Added

- Eight auto-hide effects with speed, delays, reveal strip and edge hint, four color
  modes including a custom background, text and accent, an optional window outline, and a
  tabbed settings panel with a scrollable live preview.

## [1.2.1] - 2026-10-04

### Fixed

- A leftover empty preview bubble, and app icons going blank.

## [1.2.0] - 2026-10-04

### Added

- An attention indicator for apps that ask for focus.

## [1.1.0] - 2026-10-04

### Added

- Per-dock monitor selection with a layout per screen, bar detection and reserved space.

## [1.0.0] - 2026-10-03

### Added

- Up to 12 docks with pinned apps, live previews, auto-hide, reserved space and per-edge
  margins.

[2.3.2]: https://github.com/qempexe/omarchy-multi-docks/compare/v2.3.1...v2.3.2
[2.3.1]: https://github.com/qempexe/omarchy-multi-docks/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/qempexe/omarchy-multi-docks/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/qempexe/omarchy-multi-docks/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/qempexe/omarchy-multi-docks/compare/v2.0.3...v2.1.0
[2.0.3]: https://github.com/qempexe/omarchy-multi-docks/compare/v2.0.2...v2.0.3
[2.0.2]: https://github.com/qempexe/omarchy-multi-docks/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/qempexe/omarchy-multi-docks/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/qempexe/omarchy-multi-docks/compare/v1.2.1...v2.0.0
[1.2.1]: https://github.com/qempexe/omarchy-multi-docks/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/qempexe/omarchy-multi-docks/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/qempexe/omarchy-multi-docks/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/qempexe/omarchy-multi-docks/releases/tag/v1.0.0
