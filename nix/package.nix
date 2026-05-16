{
  lib,
  stdenvNoCC,
  grub2,
  fontSize ? 28,
  fontRange ? "0x20-0x7e,0xa0-0xff,0x2010-0x2026",
}:

stdenvNoCC.mkDerivation {
  pname = "minimal-grub-theme";
  version = "0-unstable-2026-05-16";

  src = lib.cleanSource ../.;

  nativeBuildInputs = [ grub2 ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -d "$out"
    install -m 0644 minimal/theme.txt "$out/theme.txt"

    grub-mkfont \
      -s ${toString fontSize} \
      -n custom \
      -r ${lib.escapeShellArg fontRange} \
      -o "$out/custom.pf2" \
      minimal/original.ttf

    runHook postInstall
  '';

  meta = {
    description = "Minimal text-only GRUB theme";
    platforms = lib.platforms.linux;
  };
}
