# Release 1 mobile launcher icons

Launcher-only update for Admin, Resident and Security. The approved 1254×1254 RGB
masters remain byte-for-byte unchanged in their respective branding folders.
No in-app, login, header, web, desktop or iOS launch artwork was replaced.

## Reproduction

From the root, with the existing Functions dependencies installed:

```sh
node tools/branding/generate_mobile_icons.cjs
node tools/branding/generate_mobile_icons.cjs --check
```

The script uses the existing Sharp dependency without installing/upgrading it.
The mobile fields in each app's `pubspec.yaml` point to the approved master and
prepared Android layers. Existing web/desktop generation settings are unchanged;
use the scoped script above to avoid regenerating those unrelated platforms.
The icon masters and derivatives are generator inputs, not new Flutter UI assets.

## Android

Per app: five legacy `mipmap-*/ic_launcher.png` exports (48/72/96/144/192 px),
five opaque `drawable-*/ic_launcher_background.png` exports and five transparent
`drawable-*/ic_launcher_foreground.png` exports (108/162/216/324/432 px), plus
`mipmap-anydpi-v26/ic_launcher.xml`. Manifest icon names remain `ic_launcher`.

The intact master is proportionally resized to 660×660 within a 1080×1080 layer.
Its H, role symbol and cyan glow lie inside the central 66dp safe circle; only dark
navy corner background lies outside. Edge-pixel extension fills the surrounding
canvas continuously, avoiding an internal square boundary. No background is
removed or color-keyed, no corners are baked into the master, and no symbol is
cropped. The legacy icon uses the central 72dp viewport of the same composition.
Square and circle previews were inspected locally.

**Limitation:** the artwork is flattened on the background layer; the foreground
is transparent. Android applies its normal launcher mask, but there is no separate
foreground-depth/parallax effect. True separated foreground artwork still needs
approved transparent/layered source files. No monochrome substitute was invented.

Admin and Resident Android 12 themes previously reused `ic_launcher`. Dedicated
`launcher_splash` mipmaps/XML and foreground copies preserve the exact old splash
pixels and inset. Only the theme's resource pointer changes. Existing background
colors and Security's dedicated splash resources remain unchanged.

## iOS

Each existing AppIcon catalog retains its 25 iPhone/iPad/marketing slots and
21 unique filenames, including 1024×1024. All are RGB, opaque, proportional exports
of the correct role master. Catalog layouts, project AppIcon selection, signing,
deployment targets and build configuration are unchanged.

## Validation

- Deterministic check: 117 generated PNGs match the supplied masters/recipe.
- Dimensions/opacity: all 75 iOS catalog slots and all three Android density sets pass.
- Android resources: AAPT2 compilation passes for all three apps.
- iOS: Xcode `actool --platform iphoneos` catalog compilation passes for all three.
  The first sandboxed simulator compilation could not access CoreSimulator; the
  subsequent local device-target compilations succeeded without signing/deployment.
- Master hashes, six excluded files, and preserved splash copies checked unchanged.
- Node syntax check and `git diff --check` pass.

No application test suites or complete app builds were needed for resource-only
changes. Install fresh rebuilt apps to inspect real launcher masks and confirm
cold-launch transitions on Android and iOS. Preview inspection is not device
acceptance; no app was installed, deployed or published.
