# Contributing

Multi-Docks is a service that keeps the docks and their config, a window per dock, the
settings panel, and plain JavaScript for the looks and the hide effects. Most changes
touch one or two files.

```
qml/Service.qml              config, theme, bar detection, layout, reserved space
qml/dock/DockWindow.qml      one dock: icons, previews, menus, auto-hide
qml/dock/Spacer.qml          the reserved space for one edge of one monitor
qml/dock/SearchField.qml     the app picker's search box
qml/settings/SettingsPanel.qml  the panel: header, preview, tabs, Docks and About
qml/settings/SettingRow.qml  one setting: toggle, number, choices, tiles, colors
qml/js/Style.js              the look settings, the ready made looks, room for the ends
qml/js/Paint.js              draws a dock's body
qml/js/Trace.js              walks a shape's outline
qml/js/Effects.js            the hide effect math
qml/js/parts/                Ends, Surfaces, Lines, Ornaments: one entry per kind
```

## A new setting

1. Add a default to `defaults` in `qml/Service.qml`, and a range to `ranges` if it is a
   number. `cleanDock` keeps every saved value inside them.
2. Add a row to its tab in `rows` in `qml/settings/SettingsPanel.qml`: a `key` that never
   changes once released, a `label`, a `kind` (`bool`, `int`, `enum`, `style`, `scheme`
   or `palette`), a `fallback` and a one-sentence `hint`. `scoped: true` makes it follow
   **Apply to**, and `auto: true` dims it while auto-hide is off.
3. Read it as `cfg.<key>` in `DockWindow.qml`.

## A new end, surface, line or ornament

Add an entry to its file in `qml/js/parts/`, with a label, a one-sentence about and its
drawing. The tiles in the settings and the dock itself both draw through `Paint.js`, so
there is nothing else to wire up.

## Rules

- `qml/js/` stays pure: no Qt, so `tests/test_style.js` can run it in node.
- Commands are argument arrays, never a shell line with values pasted in.
- Only the spacers reserve space; a dock window never does.
- Previews are only captured while they are open, and nothing goes to disk or the network.
- Text is plain text only.
- ES6 JavaScript: `const` and `let`, and arrow functions for callbacks.

## Tests

```bash
node tests/test_style.js
```

It checks how saved looks are cleaned, that every ready made look only uses real
values, that every end, surface, line and ornament paints on every edge, the room the
ends leave for the icons, and the colors.

After installing a changed copy, run `omarchy restart shell`: the shell keeps the old
QML loaded otherwise.

Everyone taking part is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).
