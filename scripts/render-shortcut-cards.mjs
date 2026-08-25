#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repository = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const assets = join(repository, "docs", "assets");
const sources = join(assets, "shortcut-cards");
const template = readFileSync(join(sources, "template.svg"), "utf8");

const escapeXml = (value) => String(value)
  .replaceAll("&", "&amp;")
  .replaceAll("<", "&lt;")
  .replaceAll(">", "&gt;");

const widthFor = (label) => {
  if (label === "SPACE") return 146;
  if (label === "ENTER") return 138;
  if (label === "TAB") return 104;
  if (label === "1–9") return 98;
  if (label.length > 10) return 370;
  if (label.length > 5) return 170;
  if (label.length > 3) return 118;
  if (label.length > 1) return 82;
  return 62;
};

const keys = (tokens, y) => {
  let x = 72;
  const parts = ['  <g filter="url(#shadow)">'];
  for (const token of tokens) {
    if (token === "/" || token === "→" || token === "+") {
      parts.push(`    <text x="${x + 7}" y="${y + 40}" class="action">${escapeXml(token)}</text>`);
      x += token === "→" ? 54 : 42;
      continue;
    }
    const label = typeof token === "string" ? token : token.label;
    const width = typeof token === "string" ? widthFor(label) : token.width;
    const textClass = label.length > 4 ? "keytext-small" : "keytext";
    parts.push(`    <rect x="${x}" y="${y}" width="${width}" height="62" rx="10" class="key"/>`);
    parts.push(`    <text x="${x + width / 2}" y="${y + 32}" class="${textClass}">${escapeXml(label)}</text>`);
    x += width + 10;
  }
  parts.push("  </g>");
  return parts.join("\n");
};

const row = (y, tokens, description, actionX = 440, small = false) => [
  keys(tokens, y),
  `  <text x="${actionX}" y="${y + 42}" class="${small ? "action-small" : "action"}">${escapeXml(description)}</text>`,
].join("\n");

const section = (label, y) => [
  `  <text x="72" y="${y}" class="section">${escapeXml(label)}</text>`,
  `  <line x1="72" y1="${y + 20}" x2="952" y2="${y + 20}" class="divider"/>`,
].join("\n");

const text = (x, y, value, className = "action") =>
  `  <text x="${x}" y="${y}" class="${className}">${escapeXml(value)}</text>`;

const cards = [
  {
    name: "aerospace-windows-shortcuts",
    sourceName: "aerospace-windows",
    title: "AEROSPACE",
    subtitle: "WINDOWS",
    titleSize: 108,
    titleSpacing: 9,
    accent: "#89b4fa",
    accent2: "#b4befe",
    body: [
      section("WINDOW CONTROL", 350),
      row(395, ["⌥", "←", "↓", "↑", { label: "→", width: 62 }], "Focus left / down / up / right", 510, true),
      row(480, ["⌥", "⇧", "←", "↓", "↑", { label: "→", width: 62 }], "Move left / down / up / right", 570, true),
      row(565, ["⌥", "⇧", "M"], "Move window to next monitor", 440),
      row(650, ["⌥", "-"], "Shrink window 50 px", 440),
      row(735, ["⌥", "="], "Grow window 50 px", 440),
      row(820, ["⌥", "R", "→", "H", "J", "K", "L"], "Resize width / height", 580, true),
      row(905, ["⌥", "T"], "Toggle floating / tiling", 440),
      row(990, ["⌥", "/"], "Cycle tiled orientation", 440),
      row(1075, ["⌥", "Q"], "Close focused window", 440),
      row(1160, ["⌥", "ENTER"], "Open Ghostty + Herdr", 440),
      text(72, 1435, "⌥  Option     ⇧  Shift", "muted"),
    ].join("\n\n"),
  },
  {
    name: "aerospace-workspaces-shortcuts",
    sourceName: "aerospace-workspaces",
    title: "AEROSPACE",
    subtitle: "WORKSPACES",
    titleSize: 108,
    titleSpacing: 9,
    accent: "#cba6f7",
    accent2: "#f5c2e7",
    body: [
      section("WORKSPACE CONTROL", 350),
      row(405, ["⌥", "1–9"], "Switch workspace", 465),
      row(505, ["⌥", "⇧", "1–9"], "Send window to workspace", 465),
      row(605, ["⌥", "TAB"], "Next workspace", 465),
      row(705, ["⌥", "⇧", "TAB"], "Previous workspace", 465),
      row(805, [{ label: "3-FINGER HORIZONTAL", width: 370 }], "Previous / next occupied", 465, true),
      row(905, ["⌥", "CTRL", "⇧", { label: "←↓↑→ / HJKL", width: 210 }], "Move workspace by monitor", 585, true),
      section("PERSONAL PROFILE", 1055),
      text(72, 1125, "1  Ghostty    ·    2  VSCodium    ·    3  Zen", "action"),
      text(72, 1435, "⌥ Option   CTRL Control   ⇧ Shift", "muted"),
    ].join("\n\n"),
  },
  {
    name: "herdr-terminal-shortcuts",
    sourceName: "herdr-terminal",
    title: "HERDR",
    subtitle: "TERMINAL",
    titleSize: 132,
    titleSpacing: 14,
    accent: "#a6e3a1",
    accent2: "#94e2d5",
    body: [
      section("PREFIX TRANSLATED", 350),
      text(72, 405, "Press CONTROL + B, release, then press the command key", "action-small"),
      row(445, ["⌃", "B", "→", "V"], "Vertical pane split", 570),
      row(535, ["⌃", "B", "→", "-"], "Horizontal pane split", 570),
      row(625, ["⌃", "B", "→", "H", "J", "K", "L"], "Focus left / down / up / right", 610, true),
      row(715, ["⌃", "B", "→", "⇧", "N"], "New workspace", 570),
      row(805, ["⌃", "B", "→", "W"], "Workspace picker", 570),
      row(895, ["⌃", "B", "→", "C"], "New tab", 570),
      row(985, ["⌃", "B", "→", "P", "/", "N"], "Previous / next tab", 570),
      row(1075, ["⌃", "B", "→", "Z"], "Toggle pane zoom", 570),
      row(1165, ["⌃", "B", "→", "X"], "Close pane", 570),
      text(72, 1435, "⌃  Control     ⇧  Shift", "muted"),
    ].join("\n\n"),
  },
  {
    name: "yazi-shortcuts",
    sourceName: "yazi",
    title: "YAZI",
    subtitle: "FILE MANAGER",
    titleSize: 132,
    titleSpacing: 16,
    accent: "#b4befe",
    accent2: "#cba6f7",
    body: [
      section("NAVIGATION", 350),
      row(395, ["H", "J", "K", "L"], "Move left / down / up / right", 424),
      row(480, ["ENTER", "/", "L"], "Open file or directory", 424),
      row(565, ["1–9", "/", "T", "T"], "Switch tab / new tab", 424),
      section("FILE OPERATIONS", 690),
      row(735, ["SPACE"], "Toggle selection", 424),
      row(820, ["Y", "/", "X"], "Copy / cut", 424),
      row(905, ["P", "/", "⇧", "P"], "Paste / overwrite", 424),
      row(990, ["A", "/", "R"], "Create / rename", 424),
      row(1075, ["D", "/", "⇧", "D"], "Trash / delete permanently", 424),
      section("SEARCH & SESSION", 1185),
      row(1225, ["S", "/", "⇧", "S"], "Search names / contents", 424),
      row(1305, ["Z", "/", "⇧", "Z"], "Jump with fzf / zoxide", 424),
      row(1385, ["Q", "/", "⇧", "Q"], "Quit + follow / quit + stay", 424),
      text(72, 1482, "F1 or ~ opens the complete built-in help", "muted"),
    ].join("\n\n"),
  },
];

const findExecutable = (candidates) => candidates.find((candidate) => {
  try {
    execFileSync("test", ["-x", candidate]);
    return true;
  } catch {
    return false;
  }
});

const brewPrefix = process.env.HOMEBREW_PREFIX || "/opt/homebrew";
const resvg = findExecutable([join(brewPrefix, "bin", "resvg"), "/usr/local/bin/resvg"]);
const magick = findExecutable([
  join(brewPrefix, "opt", "imagemagick-full", "bin", "magick"),
  "/usr/local/opt/imagemagick-full/bin/magick",
]);

if (!resvg || !magick) {
  throw new Error("resvg and imagemagick-full are required; run the repository bootstrap first");
}

const font = join(homedir(), "Library", "Fonts", "JetBrainsMonoNerdFontMono-Medium.ttf");
for (const card of cards) {
  const svg = template
    .replaceAll("{{ACCENT}}", card.accent)
    .replaceAll("{{ACCENT_2}}", card.accent2)
    .replaceAll("{{TITLE_SIZE}}", String(card.titleSize))
    .replaceAll("{{TITLE_SPACING}}", String(card.titleSpacing))
    .replaceAll("{{TITLE}}", escapeXml(card.title))
    .replaceAll("{{SUBTITLE}}", escapeXml(card.subtitle))
    .replaceAll("{{BODY}}", card.body);

  const source = join(sources, `${card.sourceName || card.name}.svg`);
  const png = join(assets, `${card.name}.png`);
  const rgba = `${png}.rgba.png`;
  writeFileSync(source, svg);

  const renderArgs = ["--width", "1024", "--height", "1536"];
  if (existsSync(font)) renderArgs.push("--use-font-file", font);
  execFileSync(resvg, [...renderArgs, source, rgba], { stdio: "inherit" });
  execFileSync(magick, [rgba, "-alpha", "off", "-strip", `PNG24:${png}`], { stdio: "inherit" });
  unlinkSync(rgba);
}

const overviewSource = join(sources, "overview.svg");
const overview = join(assets, "dotfiles-shortcuts-overview.png");
const overviewRgba = `${overview}.rgba.png`;
const overviewSvg = `
<svg xmlns="http://www.w3.org/2000/svg" width="2144" height="3316" viewBox="0 0 2144 3316">
  <rect width="2144" height="3316" fill="#11111b"/>
  <text x="1072" y="92" text-anchor="middle" font-family="Helvetica Neue, sans-serif" font-size="62" font-weight="300" letter-spacing="10" fill="#cdd6f4">DOTFILES SHORTCUT OVERVIEW</text>
  <line x1="32" y1="140" x2="2112" y2="140" stroke="#45475a" stroke-width="2"/>
  <image href="../aerospace-windows-shortcuts.png" x="32" y="172" width="1024" height="1536"/>
  <image href="../aerospace-workspaces-shortcuts.png" x="1088" y="172" width="1024" height="1536"/>
  <image href="../herdr-terminal-shortcuts.png" x="32" y="1748" width="1024" height="1536"/>
  <image href="../yazi-shortcuts.png" x="1088" y="1748" width="1024" height="1536"/>
</svg>`.trimStart();
writeFileSync(overviewSource, overviewSvg);

const overviewArgs = ["--width", "2144", "--height", "3316"];
if (existsSync(font)) overviewArgs.push("--use-font-file", font);
execFileSync(resvg, [...overviewArgs, overviewSource, overviewRgba], { stdio: "inherit" });
execFileSync(magick, [overviewRgba, "-alpha", "off", "-strip", `PNG24:${overview}`], { stdio: "inherit" });
unlinkSync(overviewRgba);

console.log(`Rendered ${cards.length} shortcut cards and ${overview}`);
