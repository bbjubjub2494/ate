{ stdenv
, config
, gnome3
, gnumake
, lib
, makeWrapper
, pkgconfig
, pkgs
, rofi
, xurls
}:
#
# Pass config like
#
# nixpkgs.config.ate.options = { BACKGROUND_COLOR = "#000000"; }
# nixpkgs.config.ate.keybindings = { INCREMENT_FONT = "control+plus"; }
#
# See https://developer.gnome.org/gdk3/stable/gdk3-Windows.html#GdkModifierType for possible modifiers.
# The format is "(<modifier>\+)+<keyname>" and the <modifier> will be used in the form GDK_<modifier>_MASK.
# The keyname will be passed to https://developer.gnome.org/gdk3/stable/gdk3-Keyboard-Handling.html#gdk-keyval-from-name
#
# For possible options see config.default.h
#
stdenv.mkDerivation {
  name = "ate-0.0.0";

  buildInputs = [ gnome3.vte or pkgs.vte ];
  nativeBuildInputs = [ pkgconfig gnumake makeWrapper ];

  # filter the .nix files from the repo
  src = lib.cleanSourceWith {
    filter = name: _type:
      let
        baseName = baseNameOf (toString name);
      in ! (lib.hasSuffix ".nix" baseName);
    src = lib.cleanSource ./.;
  };

  CONFIG_CFLAGS = let
    pipecmd = pkgs.writeScript "pipecmd.sh" ''
      #! /bin/sh
      ${xurls}/bin/xurls | sort | uniq | ${rofi}/bin/rofi -dmenu | xargs -r firefox
    '';
    defaultConfig = { PIPECMD = toString pipecmd; BACKGROUND_OPACITY = 0.8; };
    mkEscapedValue = name: value:
      let
        # escape the value for the macro defintion
        # int's and floats aren't quoted but converted to string instead
        type = builtins.typeOf value;
        v =
          if lib.elem type [ "float" "int" ] then
            toString value
          else lib.escapeShellArg ''"${value}"'';
      in v;

    stringDefines = lib.mapAttrs mkEscapedValue (defaultConfig // (config.ate.options or {}));
    keybindings = (config.ate.keybindings or {});
    listOfKeybindings = lib.mapAttrsToList (key: value: let
      keyList = lib.reverseList (lib.splitString "+" value);
      modifiers = builtins.tail keyList;
      keyValue = builtins.head keyList;
    in {
      "${key}_KEYVAL" = mkEscapedValue "" keyValue;
      "${key}_MODIFIER_MASK" = ''"${lib.concatStringsSep " | " (map (m: "GDK_${lib.toUpper m}_MASK") modifiers)}"'';
    }) keybindings;
    keybindingDefines = lib.foldr (accu: val: accu // val) {} listOfKeybindings;
    mkCFlag = key: value: "-D${key}=${value}";
    configFlags = lib.mapAttrsToList mkCFlag (keybindingDefines // stringDefines);
  in lib.concatStringsSep " " configFlags;

  installPhase = ''
    mkdir -p $out/bin
    cp ate $out/bin
  '';
}
