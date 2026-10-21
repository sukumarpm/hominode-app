// Native splash derivatives only; never regenerates launcher icons or changes approved masters.
const sharp = require("../../functions/node_modules/sharp");
const fs = require("fs/promises");
const path = require("path");
process.chdir(path.resolve(__dirname, "../.."));
(async () => {
  for (const [app, folder, role] of [
    ["hominode-admin/admin_app", "assets", "admin"],
    ["resident_app", "lib/assets", "resident"],
    ["security_app", "lib/assets", "security"],
  ]) {
    const source = `${app}/${folder}/branding/${role}_transparent.png`;
    for (const [density, scale] of [
      ["mdpi", 1],
      ["hdpi", 1.5],
      ["xhdpi", 2],
      ["xxhdpi", 3],
      ["xxxhdpi", 4],
    ]) {
      const file = `${app}/android/app/src/main/res/drawable-${density}/branding_splash.png`;
      await fs.mkdir(path.dirname(file), { recursive: true });
      await sharp(source)
        .resize(136 * scale, 136 * scale)
        .extend({
          top: 28 * scale,
          bottom: 28 * scale,
          left: 28 * scale,
          right: 28 * scale,
          background: { r: 0, g: 0, b: 0, alpha: 0 },
        })
        .png()
        .toFile(file);
    }
    for (const [scale, suffix] of [
      [1, ""],
      [2, "@2x"],
      [3, "@3x"],
    ]) {
      // Resize from the approved source, never enlarge a small derivative.
      await sharp(source)
        .resize(136 * scale, 136 * scale)
        .extend({
          top: 28 * scale,
          bottom: 28 * scale,
          left: 28 * scale,
          right: 28 * scale,
          background: { r: 0, g: 0, b: 0, alpha: 0 },
        })
        .png()
        .toFile(
          `${app}/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage${suffix}.png`,
        );
    }
  }
})().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
