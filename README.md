# Darkfi - Nixos impure flake

## Installation (impure)

This flake sticks to the initial design and uses Makefiles maintained by the
DarkFi core team.

Using nix builders would make the package evaluation pure, but would although
lead to duplicate and inevitably to an out of date flake.

Make this flake pure


### Building the flake
To build the flake on the terminal with the project as the current working directory

```sh
nix build .#packages.x86_64-linux.default
```

💡 Need to have the sandbox thing from below set in the system configuration

### Prerequisites

The flake buildPhases need network access that are by default disabled by nix.

You need to first *_relax_ nix build sandbox parameter to allow impure builds.

Either in your nixos configuration:

```nix
# configuration.nix
nix.settings.sandbox = "relaxed"
```

or exceptionally via command-line as an argument of an installation command.

```sh
nix-env -i github:darkrenaissance/darki?dir=contrib/nix --no-sandbox
```

### Declaration

Import it in your flake inputs.

```sh
inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    darkfi.url = "github:pipelight/darkfi.nix";
};
```

Add the packages to your environment or to a specific users.

```nix
environment.systemPackages = with pkgs; [
    inputs.darkfi.packages.${system}.default
];
```

## Enable background services

Add a user systemd unit with home-manager.

```nix
# home.nix
## Darkirc messaging background service
systemd.user.services."darkirc" = {
  enable = true;
  after = ["network.target"];
  serviceConfig = {
    ExecStart = "${darkfi}/bin/darkirc";
  };
  wantedBy = ["multi-user.target"];
};
```

## Running as a nix option with flakes
To simply configure darkirc as a nix module anywhere in your nix configuration, like this:

```nix
darkfi-service.enable = true;
```

The concept used here is explained in this video by VimJoyer: https://www.youtube.com/watch?v=vYc6IzKvAJQ
### Step 1: Add the input to your flake
Add this to your flake.nix
```nix
  inputs = {
    darkfi.url = "github:pipelight/darkfi.nix";
  };

  # NOTE important part here is the @inputs 
  outputs = { nixpkgs, home-manager, unstable, ... }@inputs: {
      nixosConfigurations = {
    # your nixos configuration(s) here...
    };
  };
```

### Step 2: Add the configuration for the nix module
Create a file called `darkfi-service.nix` somewhere in your nixos configuration folder.

Here we define the option `darkfi-service` for later use in our nix configuration
```nix

{ config, lib, pkgs, inputs, ... }:

# NOTE you may need to replace "x86_64-linux" with your system
let darkfiPkg = inputs.darkfi.packages."x86_64-linux".default;

in {
  options.darkfi-service.enable = lib.mkEnableOption "Enables darkfi";

  config = lib.mkIf config.darkfi-service.enable {
    nix.settings.sandbox = "relaxed";

    # NOTE you may remove weechat, if you are using a different IRC client
    environment.systemPackages = [ pkgs.weechat darkfiPkg ];

    systemd.user.services.darkirc = {
      enable = true;
      after = [ "network.target" ];
      serviceConfig = { ExecStart = "${darkfiPkg}/bin/darkirc"; };
      wantedBy = [ "default.target" ]; 
    };
  };
}
```

### Step 3: Create a `default.nix` 
To have access to our custom module anywhere, we create a `default.nix` file somewhere in your nixos configuration folder. 

The path of the `darkfi-service.nix` is relative from the location of the `default.nix`

```nix
{ ... }:

{
  imports = [
    ./darkfi-service.nix
  ];
}
```

### Step 4: Commit these new files to your version control
Nix Flakes only recognize files that are checked into the version control, so make sure you have these files committed to your nixos system configuration version control.

### Step 5: Enable the option in your system configuration
Somewhere in your nixos system configuration you can now simply enable darkfi as an option with:

```nix
darkfi-service.enable = true;
```

Rebuild your system and check if the service is running with:

```sh
systemctl --user status darkirc.service

# If its the first time running the service, you need to restart it once
systemctl --user restart darkirc.service
```

The config for darkirc will be in `~/.config/darkfi/darkirc_config.toml`
