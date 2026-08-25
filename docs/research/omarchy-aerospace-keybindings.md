---
layout: default
title: Omarchy and AeroSpace keybindings
---

# Omarchy and AeroSpace keybindings

## Question

Which current Omarchy navigation bindings can AeroSpace reproduce on macOS,
including grouping and moving groups between monitors?

## Findings

Omarchy uses `Super + Arrow` to focus windows, `Super + Shift + Arrow` to move
them, `Super + Tab` and `Super + Shift + Tab` for next and previous workspaces,
and `Super + Shift + Alt + Arrow` to move an entire workspace to the adjacent
monitor. It also uses `Super + T` for floating/tiling. These bindings are in the
[official Omarchy tiling configuration](https://github.com/basecamp/omarchy/blob/93010924047d09f62f702bf8b5c07d0149c11943/default/hypr/bindings/tiling.lua).

This AeroSpace setup treats macOS Option as Omarchy's Super modifier. Control
takes the place of Omarchy's additional Alt modifier, so moving a whole
workspace uses `Option + Control + Shift + Arrow`. Existing Vim-style H/J/K/L
bindings remain as aliases.

AeroSpace's [`join-with` command](https://nikitabobko.github.io/AeroSpace/commands#join-with)
creates a common parent container for the focused window and its directional
neighbor. However, [`move-node-to-monitor`](https://nikitabobko.github.io/AeroSpace/commands#move-node-to-monitor)
moves the focused window rather than that parent container. Direct root or
parent-container movement remains an
[open AeroSpace request](https://github.com/nikitabobko/AeroSpace/issues/940).

## Decision

Match Omarchy's arrow, workspace-cycle, floating, and whole-workspace monitor
bindings. Keep service-mode `join-with` for arranging local groups. To move a
group intact across displays, move its entire workspace; do not present focused
window movement as group movement.

Finder is a floating utility by default, matching the requested macOS workflow.
Floating is only its initial layout and can be toggled with `Option + T`.
