#!/usr/bin/env node
// Deterministic launcher exports only. Never writes in-app or splash artwork.
// Uses the repository's existing Sharp dependency; does not install packages.
const fs = require("node:fs/promises");
const path = require("node:path");
const crypto = require("node:crypto");
const sharp = require("../../functions/node_modules/sharp");
const root = path.resolve(__dirname, "../..");
const apps = [
  ["Admin", "hominode-admin/admin_app", "assets/branding", "admin"],
  ["Resident", "resident_app", "lib/assets/branding", "resident"],
  ["Security", "security_app", "lib/assets/branding", "security"],
];
const densities = [
  ["mdpi", 1],
  ["hdpi", 1.5],
  ["xhdpi", 2],
  ["xxhdpi", 3],
  ["xxxhdpi", 4],
];
const check = process.argv.includes("--check");
let verified = 0;
async function output(file, bytes) {
  if (check) {
    if (!(await fs.readFile(file)).equals(bytes))
      throw Error(`Stale launcher asset: ${path.relative(root, file)}`);
    verified++;
  } else {
    await fs.mkdir(path.dirname(file), { recursive: true });
    await fs.writeFile(file, bytes);
  }
}
(async () => {
  for (const [role, app, folder, name] of apps) {
    const source = await fs.readFile(
      path.join(root, app, folder, `${name}.png`),
    );
    const meta = await sharp(source).metadata();
    if (meta.width !== 1254 || meta.height !== 1254 || meta.hasAlpha)
      throw Error(`Unexpected ${role} master`);
    // Fit the intact master into the central 660px / 66dp square of a
    // 1080px / 108dp layer. The supplied H, inner symbol and cyan glow fit
    // inside its inscribed safe circle; only navy corner background lies
    // outside. No source pixels are cropped during export.
    // Extend edge pixels, rather than alpha-keying or inventing/removing artwork.
    // Put the complete flattened art on the background; foreground is empty.
    const art = await sharp(source)
      .resize(660, 660, { kernel: "lanczos3" })
      .removeAlpha()
      .png()
      .toBuffer();
    const background = await sharp(art)
      .extend({
        top: 210,
        bottom: 210,
        left: 210,
        right: 210,
        extendWith: "copy",
      })
      .png()
      .toBuffer();
    const foreground = await sharp({
      create: {
        width: 1080,
        height: 1080,
        channels: 4,
        background: { r: 0, g: 0, b: 0, alpha: 0 },
      },
    })
      .png()
      .toBuffer();
    const legacy = await sharp(background)
      .extract({ left: 180, top: 180, width: 720, height: 720 })
      .png()
      .toBuffer();
    await output(
      path.join(root, app, folder, "launcher-adaptive-background.png"),
      background,
    );
    await output(
      path.join(root, app, folder, "launcher-adaptive-foreground.png"),
      foreground,
    );
    await output(path.join(root, app, folder, "launcher-android.png"), legacy);
    for (const [density, scale] of densities) {
      const res = path.join(root, app, "android/app/src/main/res");
      await output(
        path.join(res, `mipmap-${density}/ic_launcher.png`),
        await sharp(legacy)
          .resize(Math.round(48 * scale))
          .removeAlpha()
          .png()
          .toBuffer(),
      );
      for (const [label, buffer] of [
        ["background", background],
        ["foreground", foreground],
      ]) {
        await output(
          path.join(res, `drawable-${density}/ic_launcher_${label}.png`),
          await sharp(buffer)
            .resize(Math.round(108 * scale))
            .png()
            .toBuffer(),
        );
      }
    }
    const catalog = path.join(
      root,
      app,
      "ios/Runner/Assets.xcassets/AppIcon.appiconset",
    );
    const contents = JSON.parse(
      await fs.readFile(path.join(catalog, "Contents.json"), "utf8"),
    );
    const seen = new Map();
    for (const image of contents.images) {
      const dimensions = image.size.split("x").map(Number);
      const pixels = dimensions[0] * Number(image.scale.replace("x", ""));
      if (
        dimensions[0] !== dimensions[1] ||
        !Number.isInteger(pixels) ||
        !image.filename
      )
        throw Error(`Invalid ${role} icon slot`);
      if (seen.has(image.filename) && seen.get(image.filename) !== pixels)
        throw Error("Conflicting AppIcon slots");
      if (seen.has(image.filename)) continue;
      seen.set(image.filename, pixels);
      await output(
        path.join(catalog, image.filename),
        await sharp(source)
          .resize(pixels, pixels)
          .removeAlpha()
          .png()
          .toBuffer(),
      );
    }
    console.log(
      `${role}: 5 legacy Android icons, 10 adaptive layer images, ${contents.images.length} iOS slots / ${seen.size} opaque PNGs; master SHA256 ${crypto.createHash("sha256").update(source).digest("hex")}`,
    );
  }
  if (check)
    console.log(`${verified} generated PNGs match their approved sources.`);
})().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
