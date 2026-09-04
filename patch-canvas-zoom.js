#!/usr/bin/env node
/**
 * ExcaliDash contains canvasZoomForwarding.ts which intercepts plain wheel
 * events and converts them to synthetic ctrl+wheel (zoom).
 * This breaks trackpad two-finger scrolling (which normally pans the canvas in Excalidraw).
 * This script restores native Excalidraw navigation behavior:
 * - Two-finger drag on trackpad = pans around the canvas
 * - Pinch-to-zoom on trackpad = zooms
 * - Ctrl + mouse wheel = zooms
 * - Normal mouse wheel = scrolls/pans
 */
const fs = require("fs");
const path = require("path");

const targetDir = process.argv[2] || "/var/www/html/assets";

if (!fs.existsSync(targetDir)) {
  console.log(`[PATCH] Directory ${targetDir} does not exist, skipping.`);
  process.exit(0);
}

let patchedCount = 0;
for (const file of fs.readdirSync(targetDir)) {
  if (!file.endsWith(".js")) continue;
  const filePath = path.join(targetDir, file);
  let content = fs.readFileSync(filePath, "utf8");

  if (content.includes("_isFakeZoom")) {
    console.log(`[PATCH] Restoring native Excalidraw trackpad navigation in ${file}...`);
    const beforeLength = content.length;

    // 1. Disable the capturing wheel event listener on the editor container
    content = content.replace(
      /addEventListener\(["']wheel["'],\s*([a-zA-Z0-9_$]+),\s*\{capture:!0,passive:!1\}\)/g,
      'addEventListener("disabled_wheel",$1)'
    );

    // 2. Disable the synthetic _isFakeZoom zoom event emission branch
    content = content.replace(
      /!([a-zA-Z0-9_$]+)\._isFakeZoom/g,
      "false"
    );

    if (content.length !== beforeLength || content.includes('addEventListener("disabled_wheel"')) {
      fs.writeFileSync(filePath, content, "utf8");
      patchedCount++;
      console.log(`[PATCH] Successfully patched ${file}! Native trackpad panning restored.`);
    }
  }
}

if (patchedCount === 0) {
  console.log("[PATCH] No canvas zoom hijack found to patch (already patched or not present).");
}
