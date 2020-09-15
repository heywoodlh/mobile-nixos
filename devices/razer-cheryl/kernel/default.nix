{
  mobile-nixos
, fetchFromGitHub
, kernelPatches ? [] # FIXME
, buildPackages
, dtbTool
}:

let
  inherit (buildPackages) dtc;
in

(mobile-nixos.kernel-builder-gcc49 {
  configfile = ./config.aarch64;

  file = "Image.gz-dtb";
  hasDTB = true;

  version = "4.4.233";
  src = fetchFromGitHub {
    owner = "LineageOS";
    repo = "android_kernel_razer_msm8998";
    rev = "d216cec5945665e51bfa04dbe0f74626ecd8801c";
    sha256 = "0jalrqxk84m0kh12cpqis1dx5jw4rc75g3qjz52idlrxzr5yk7lf";
  };


  patches = [
    ./0001-mobile-nixos-Adds-and-sets-BGRA-as-default.patch
    ./0003-arch-arm64-Add-config-option-to-fix-bootloader-cmdli.patch
  ];

  isModular = false;
}).overrideAttrs({ postInstall ? "", postPatch ? "", nativeBuildInputs, ... }: {
  installTargets = [ "zinstall" "Image.gz-dtb" "install" ];
  postPatch = postPatch + ''
    # FIXME : factor out
    (
    # Remove -Werror from all makefiles
    local i
    local makefiles="$(find . -type f -name Makefile)
    $(find . -type f -name Kbuild)"
    for i in $makefiles; do
      sed -i 's/-Werror-/-W/g' "$i"
      sed -i 's/-Werror=/-W/g' "$i"
      sed -i 's/-Werror//g' "$i"
    done
    )
  '';
  nativeBuildInputs = nativeBuildInputs ++ [ dtc ];

  postInstall = postInstall + ''
    cp -v "$buildRoot/arch/arm64/boot/Image.gz-dtb" "$out/"
  '';
})
