{ config, pkgs, ... }:
{
  home.packages = with pkgs; [ hyprlock hypridle ];

  xdg.configFile."hypr/hyprlock.conf".text = ''
    source = ~/.config/hypr/hyprlock-colors.conf

    general {
        hide_cursor = true
        grace = 2
    }

    background {
        monitor =
        # Blurs whatever the current wallpaper is rather than a fixed image.
        path = screenshot
        blur_passes = 3
        blur_size = 8
        brightness = 0.6
    }

    input-field {
        monitor =
        size = 280, 48
        outline_thickness = 2
        dots_size = 0.25
        dots_spacing = 0.3
        dots_center = true
        outer_color = $lockPrimary
        inner_color = $lockSurface
        font_color = $lockOnSurface
        fade_on_empty = false
        placeholder_text = <span foreground="##888888">password</span>
        hide_input_base_color = $lockPrimary
        rounding = 24
        check_color = $lockPrimary
        position = 0, -60
        halign = center
        valign = center
    }

    label {
        monitor =
        text = $TIME
        color = $lockOnSurface
        font_size = 84
        font_family = JetBrainsMono Nerd Font
        position = 0, 80
        halign = center
        valign = center
    }

    label {
        monitor =
        text = cmd[update:43200000] date +"%A, %d %B"
        color = $lockOnSurface
        font_size = 16
        font_family = JetBrainsMono Nerd Font
        position = 0, 10
        halign = center
        valign = center
    }
  '';

  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
        lock_cmd = pidof hyprlock || hyprlock
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on
    }

    listener {
        timeout = 300
        on-timeout = loginctl lock-session
    }

    listener {
        timeout = 600
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
    }
  '';

  xdg.configFile."wlogout/layout".text = ''
    {
        "label" : "lock",
        "action" : "hyprlock",
        "text" : "Lock",
        "keybind" : "l"
    }
    {
        "label" : "logout",
        "action" : "hyprctl dispatch exit",
        "text" : "Logout",
        "keybind" : "e"
    }
    {
        "label" : "suspend",
        "action" : "systemctl suspend",
        "text" : "Suspend",
        "keybind" : "u"
    }
    {
        "label" : "reboot",
        "action" : "systemctl reboot",
        "text" : "Reboot",
        "keybind" : "r"
    }
    {
        "label" : "shutdown",
        "action" : "systemctl poweroff",
        "text" : "Shutdown",
        "keybind" : "s"
    }
  '';

  xdg.configFile."wlogout/style.css".text = ''
    * {
        background-image: none;
        box-shadow: none;
        font-family: "JetBrainsMono Nerd Font";
    }

    window {
        background-color: rgba(10, 10, 14, 0.85);
    }

    button {
        color: #e5e1e9;
        background-color: rgba(31, 30, 38, 0.9);
        border: 2px solid rgba(72, 69, 83, 0.9);
        border-radius: 16px;
        margin: 10px;
        background-repeat: no-repeat;
        background-position: center;
        background-size: 25%;
    }

    button:focus, button:hover {
        background-color: rgba(199, 191, 255, 0.25);
        border-color: #c7bfff;
        outline-style: none;
    }
  '';

  xdg.configFile."fuzzel/fuzzel.ini".text = ''
    [main]
    font=JetBrainsMono Nerd Font:size=11
    terminal=kitty
    layer=overlay
    width=40
    lines=12
    horizontal-pad=20
    vertical-pad=16
    inner-pad=8

    [border]
    radius=14
    width=2

    [colors]
    background=14131aee
    text=e5e1e9ff
    match=c7bfffff
    selection=2a2833ff
    selection-text=e5e1e9ff
    selection-match=c7bfffff
    border=484553ff
  '';
}
