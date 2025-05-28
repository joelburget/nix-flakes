{ pkgs }:
{
	google-ops-agent = (pkgs.callPackage ./google-ops-agent/package.nix {}).ops-agent-go;
	modules = import ./modules.nix;
}
