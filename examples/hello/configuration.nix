{ config, lib, pkgs, ... }:

let
  inherit (lib.strings) makeBinPath;

  hello-gui = pkgs.mobile-nixos.stage-1.script-loader.wrap {
    name = "hello-gui";
    applet = "${pkgs.callPackage ./app {}}/libexec/app.mrb";
    env = {
      PATH = "${makeBinPath (with pkgs;[
        systemd     # journalctl
        glibc       # iconv
        utillinux   # lsblk
        input-utils # lsinput
      ])}:$PATH";
    };
  };

  tmpfsConf = {
    device = "tmpfs";
    fsType = "tmpfs";
    neededForBoot = true;
  };
in
{
  imports = [
    ./workaround-v4l_id-hang.nix
  ];

  environment.systemPackages = with pkgs; [
    hello-gui
    input-utils
  ];

  # Make the system rootfs different enough that mixing stage-1 and stage-2
  # will fail and not have weird unexpected behaviours.
  mobile.generatedFilesystems = {
    rootfs = lib.mkDefault {
      label = lib.mkForce "MOBILE_HELLO";
      id    = lib.mkForce "12345678-1324-1234-0000-D00D00000001";
    };
  };

  fileSystems = {
    "/" = lib.mkDefault {
      autoResize = lib.mkForce false;
    };
    # Nothing is saved, except for the nix store being rehydrated.
    "/tmp" = tmpfsConf;
    "/var/log" = tmpfsConf;
    "/home" = tmpfsConf;
  };
 
  mobile.boot.stage-1.bootConfig = {
    # This will be useful for debugging boot issues over serial in the default
    # configuration.
    log.level = "DEBUG";
  };

  systemd.services.hello-gui = {
    description = "GUI for the hello example of Mobile NixOS";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "always";
      SyslogIdentifier = "hello-gui";
      ExecStart = ''
        ${hello-gui}/bin/hello-gui
      '';
    };
  };

  # Only enable `adb` if we know how to.
  # FIXME: relies on implementation details. Poor separation of concerns.
  mobile.adbd.enable = (config.mobile.system.type == "android") &&
    (config.mobile.usb.mode != "gadgetfs" || config.mobile.usb.gadgetfs.functions ? ffs)
  ;

  boot.postBootCommands = lib.mkOrder (-1) ''
    brightness=10
    echo "Setting brightness to $brightness"
    if [ -e /sys/class/backlight/backlight/brightness ]; then
      echo $(($(cat /sys/class/backlight/backlight/max_brightness) * brightness / 100)) > /sys/class/backlight/backlight/brightness
    elif [ -e /sys/class/leds/lcd-backlight/max_brightness ]; then
      echo $(($(cat /sys/class/leds/lcd-backlight/max_brightness)  * brightness / 100)) > /sys/class/leds/lcd-backlight/brightness
    elif [ -e /sys/class/leds/lcd-backlight/brightness ]; then
      # Assumes max brightness is 100... probably wrong, but good enough, eh.
      echo $brightness > /sys/class/leds/lcd-backlight/brightness
    fi
  '';

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" ];
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = lib.mkForce false;
  };

  services.mingetty.autologinUser = "nixos";

  system.build = {
    app-simulator = pkgs.callPackage ./app/simulator.nix {};
  };
}
