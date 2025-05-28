{ config, lib, pkgs, ... }:

let
  cfg = config.services.google-ops-agent;

  # Convenience aliases for the packages we exported in the overlay
  opsAgent   = pkgs.google-ops-agent;   # engine + diagnostics + wrapper
  otel       = pkgs.otelopscol;
  fluentBit  = pkgs.fluent-bit;

  # Where we'll drop the user-supplied YAML (if any)
  configFile =
    if cfg.settings == {} then "/etc/google-cloud-ops-agent/config.yaml"
    else
      pkgs.writeText "ops-agent-config.yaml"
        (builtins.toJSON cfg.settings);  # simple JSON→YAML shim works for most
in
{
  ###### 1.  Module options ###################################################
  options.services.google-ops-agent = {
    enable = lib.mkEnableOption (lib.mdDoc "Enable Google Cloud Ops Agent");

    packageOpsAgent  = lib.mkOption {
      type        = lib.types.package;
      default     = opsAgent;
      defaultText = lib.literalExpression "pkgs.google-ops-agent";
      description = "Package that provides google_cloud_ops_agent_engine etc.";
    };

    packageFluentBit = lib.mkOption {
      type        = lib.types.package;
      default     = fluentBit;
      defaultText = lib.literalExpression "pkgs.fluent-bit";
      description = "Package that provides the Fluent-Bit binary.";
    };

    packageOtel = lib.mkOption {
      type        = lib.types.package;
      default     = otel;
      defaultText = lib.literalExpression "pkgs.otelopscol";
      description = "Package that provides the otelopscol binary.";
    };

    # Either drop a ready-made YAML file yourself …
    configPath = lib.mkOption {
      type        = lib.types.nullOr lib.types.path;
      default     = null;
      description = ''
        If set, the given file becomes /etc/google-cloud-ops-agent/config.yaml
        on the target system.  Mutually exclusive with `settings`.
      '';
    };

    # … or describe a small config as Nix attr-set and we'll JSON→YAML-ify it.
    settings = lib.mkOption {
      type        = lib.types.attrs;
      default     = {};
      description = ''
        Nix attr-set that will be emitted as YAML for config.yaml.
        Ignored when `configPath` is set.
      '';
    };
  };

  ###### 2.  Implementation ###################################################
  config = lib.mkIf cfg.enable {

    # Place config.yaml (either from user path or generated from settings)
    environment.etc."google-cloud-ops-agent/config.yaml".source =
      if cfg.configPath != null then cfg.configPath else configFile;

    # Main "parent" unit – validates & generates runtime files
    systemd.services.google-cloud-ops-agent = {
      description = "Google Cloud Ops Agent (parent)";
      documentation = [ "https://cloud.google.com/stackdriver/docs/solutions/agents/ops-agent" ];
      wantedBy     = [ "multi-user.target" ];
      before       = [
        "google-cloud-ops-agent-fluent-bit.service"
        "google-cloud-ops-agent-otel.service"
      ];

      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;

        # Validate & render configs for sub-agents
        ExecStart = "${cfg.packageOpsAgent}/bin/google_cloud_ops_agent_engine"
                      + " -in ${configFile}";
      };
    };

    # Fluent-Bit (logging) sub-service
    systemd.services.google-cloud-ops-agent-fluent-bit = {
      description   = "Google Cloud Ops Agent – Logging (Fluent-Bit)";
      after         = [ "network.target" "google-cloud-ops-agent.service" ];
      wants         = [ "google-cloud-ops-agent.service" ];
      partOf        = [ "google-cloud-ops-agent.service" ];
      wantedBy      = [ "multi-user.target" ];

      serviceConfig = {
        Restart      = "on-failure";
        RestartSec   = 5;

        ExecStartPre =
          "${cfg.packageOpsAgent}/bin/google_cloud_ops_agent_engine"
          + " -service=fluentbit -in ${configFile}";

        ExecStart =
          "${cfg.packageFluentBit}/bin/fluent-bit "
          + "--config /run/google-cloud-ops-agent-fluent-bit/fluent_bit_main.conf "
          + "--parser /run/google-cloud-ops-agent-fluent-bit/fluent_bit_parser.conf "
          + "--log_level info";
      };
    };

    # OpenTelemetry Collector (metrics/traces) sub-service
    systemd.services.google-cloud-ops-agent-otel = {
      description   = "Google Cloud Ops Agent – Metrics & Traces (otelopscol)";
      after         = [ "network.target" "google-cloud-ops-agent.service" ];
      wants         = [ "google-cloud-ops-agent.service" ];
      partOf        = [ "google-cloud-ops-agent.service" ];
      wantedBy      = [ "multi-user.target" ];

      serviceConfig = {
        Restart      = "on-failure";
        RestartSec   = 5;

        ExecStartPre =
          "${cfg.packageOpsAgent}/bin/google_cloud_ops_agent_engine"
          + " -service=otel -in ${configFile}";

        ExecStart =
          "${cfg.packageOtel}/bin/otelopscol "
          + "--config /run/google-cloud-ops-agent-otel/otel.yaml";
      };
    };
  };
}
