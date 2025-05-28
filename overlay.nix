final: prev: let
  opsPkgs = prev.callPackage ./google-ops-agent/package.nix {};
in {
  # expose each sub-agent and aliases under the overlay namespace
  ops-agent-go = opsPkgs.ops-agent-go;
  otelopscol   = opsPkgs.otelopscol;
  # Expose the Google-patched Fluent Bit under a dedicated name to avoid
  # overriding the vanilla pkgs.fluent-bit (which would cause recursion).
  google-fluent-bit = opsPkgs.fluent-bit;
  google-ops-agent = opsPkgs.ops-agent-go;
} 