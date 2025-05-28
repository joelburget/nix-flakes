{
	description = "SFC custom packages & modules (Ops Agent, etc.)";

	inputs = {
		nixpkgs.url     = "github:NixOS/nixpkgs/nixos-24.05";
		flake-utils.url = "github:numtide/flake-utils";
	};

	outputs = { self, nixpkgs, flake-utils, ... }:
		flake-utils.lib.eachDefaultSystem (system:
			let
				overlay = import ./overlay.nix;
				pkgs = import nixpkgs {
					inherit system;
					overlays = [ overlay ];
				};
			in {
				packages = {
					inherit (pkgs) ops-agent-go otelopscol fluent-bit google-ops-agent;
					# convenience alias for `nix build` without attr path
					default = pkgs.google-ops-agent;
				};

				overlays.default = overlay;

				nixosModules = import ./modules.nix;
			}) // {
				overlay = self.overlays.default;
				nixosModules.default = self.nixosModules.google-ops-agent;
				nixosModules.google-ops-agent = import ./google-ops-agent/module.nix;
			};
}
