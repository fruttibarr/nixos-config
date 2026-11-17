{ ... }:
# System-wide 5-band equalizer, controlled live from Quickshell
# (Control center › Sound › Equalizer, home/quickshell/services/SoundEq.qml).
#
# A PipeWire filter-chain registered as a WirePlumber *smart filter*: it is
# inserted transparently in front of whatever output is the default, so the
# default sink, volume keys and output switching all keep working on the real
# device. Every gain starts at 0 dB (bit-transparent apart from float
# rounding); Quickshell re-applies the saved curve at runtime with
# `pw-cli set-param <node> Props`, so nothing here needs to change to tune it.
let
  band = name: label: freq: q: {
    type = "builtin";
    inherit name label;
    control = { "Freq" = freq; "Q" = q; "Gain" = 0.0; };
  };
in
{
  services.pipewire.extraConfig.pipewire."60-equalizer" = {
    "context.modules" = [
      {
        name = "libpipewire-module-filter-chain";
        args = {
          "node.description" = "Equalizer";
          "media.name" = "Equalizer";
          "filter.graph" = {
            nodes = [
              # Preamp: Quickshell lowers this by the largest boost so a
              # boosted curve doesn't clip.
              { type = "builtin"; name = "eq_preamp"; label = "linear"; control = { "Mult" = 1.0; "Add" = 0.0; }; }
              (band "eq_band_1" "bq_lowshelf" 60.0 0.7)
              (band "eq_band_2" "bq_peaking" 250.0 1.0)
              (band "eq_band_3" "bq_peaking" 1000.0 1.0)
              (band "eq_band_4" "bq_peaking" 4000.0 1.0)
              (band "eq_band_5" "bq_highshelf" 12000.0 0.7)
            ];
            links = [
              { output = "eq_preamp:Out"; input = "eq_band_1:In"; }
              { output = "eq_band_1:Out"; input = "eq_band_2:In"; }
              { output = "eq_band_2:Out"; input = "eq_band_3:In"; }
              { output = "eq_band_3:Out"; input = "eq_band_4:In"; }
              { output = "eq_band_4:Out"; input = "eq_band_5:In"; }
            ];
          };
          "audio.channels" = 2;
          "audio.position" = [ "FL" "FR" ];
          "capture.props" = {
            "node.name" = "effect_input.eq";
            "media.class" = "Audio/Sink";
            "filter.smart" = true;
            "filter.smart.name" = "quickshell-eq";
          };
          "playback.props" = {
            "node.name" = "effect_output.eq";
            "node.passive" = true;
            "filter.smart" = true;
            "filter.smart.name" = "quickshell-eq";
          };
        };
      }
    ];
  };
}
