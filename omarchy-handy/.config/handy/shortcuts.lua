-- Loaded by Omarchy when Handy is the selected dictation backend. Handy's own
-- global shortcut only works under X11, so Omarchy's dictation bindings drive
-- it instead. Keep it running in the background; its recording overlay is off
-- by default on Linux.
o.launch_on_start("handy --start-hidden")
