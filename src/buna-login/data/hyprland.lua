-- The login screen's compositor (/usr/share/buna-login/hyprland.lua): one
-- window, buna-login, and nothing else.  It ends when buna-login does, so
-- greetd can start the user's session (or the greeter again).

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

hl.config({
    general = {
        gaps_in  = 0,
        gaps_out = 0,
    },
    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        -- Plain Hyprland, not start-hyprland: after a crash its watchdog
        -- restarts in safe mode, which skips this file.  Without it a crash
        -- ends the greeter and greetd starts a clean one.  Hyprland warns on
        -- screen about the missing watchdog unless told not to.
        disable_watchdog_warning = true,
        -- No "kill this app" dialog over the login screen when it is busy
        -- checking a password.
        enable_anr_dialog        = false,
    },
    -- The update-news window and the donation request would open over the
    -- login screen after an update.
    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
    -- US and Arabic keyboards; Alt+Shift switches.
    input = {
        kb_layout  = "us,ara",
        kb_options = "grp:alt_shift_toggle",
    },
})

hl.on("hyprland.start", function ()
    hl.exec_cmd("buna-login; hyprctl dispatch 'hl.dsp.exit()'")
end)
