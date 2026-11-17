{ config, pkgs, ... }:
{
  # colors.conf is matugen-generated at runtime, so it is not managed here.
  xdg.configFile."kitty/kitty.conf".text = ''
    include colors.conf

    # Explicit rather than $SHELL: the prewarmed single-instance kitty (see
    # hyprland.nix) keeps the environment it started with, so this makes the
    # shell switch apply without needing to log out first.
    shell ${pkgs.fish}/bin/fish

    # Use the *Mono* Nerd Font variant in the terminal: the plain
    # "JetBrainsMono Nerd Font" ships double-width icon glyphs, which throws
    # off cell alignment and makes text look unevenly spaced.
    font_family      JetBrainsMono Nerd Font Mono
    bold_font        JetBrainsMono Nerd Font Mono Bold
    italic_font      JetBrainsMono Nerd Font Mono Italic
    bold_italic_font JetBrainsMono Nerd Font Mono Bold Italic
    font_size 11.0

    # Force icon glyphs into a single cell so prompts/powerline segments
    # don't push the following text out of alignment.
    narrow_symbols U+E000-U+F8FF 1
    narrow_symbols U+F0000-U+FFFFD 1

    window_padding_width 10
    background_opacity 0.92
    confirm_os_window_close 0

    cursor_shape beam
    cursor_blink_interval 0.5

    tab_bar_edge top
    tab_bar_style powerline
  '';
}
