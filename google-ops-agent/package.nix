{
  lib, pkgs, stdenv, rustPlatform
}:
let
	version = "2.46.1";

	opsAgentSrc = pkgs.fetchFromGitHub {
		owner = "GoogleCloudPlatform";
		repo = "ops-agent";
		rev = "tags/${version}";
		hash = "sha256-yJerH48T7hj03wekodqYI/LMMZBtR9fKT8keK/hATkM=";
	};
in rec {
	ops-agent-go = pkgs.buildGoModule {
		pname = "google-ops-agent";
		inherit version;
		src = opsAgentSrc;
		vendorHash = "sha256-dsDyMNduxQq+mIWLz2WuExwvVLlsBRLoS2snzJIJXus=";
		subPackages = ["cmd/agent_wrapper" "cmd/google_cloud_ops_agent_diagnostics" "cmd/google_cloud_ops_agent_engine"];

		meta = {
			description = "Ops Agent is the primary agent for collecting telemetry from your Compute Engine instances";
			longDescription = "The Ops Agent is the primary agent for collecting telemetry from your Compute Engine instances. Combining the collection of logs, metrics, and traces into a single process, the Ops Agent uses Fluent Bit for logs, which supports high-throughput logging, and the OpenTelemetry Collector for metrics and traces.";
			homepage = "https://cloud.google.com/stackdriver/docs/solutions/agents/ops-agent/";
			license = lib.licenses.asl20;
			mainProgram = "google_cloud_ops_agent_engine";
			platforms = lib.platforms.linux;
			sourceProvenance = [ lib.sourceTypes.fromSource ];
		};
	};

	# Logging sub-agent used by the Ops Agent.
	# We currently rely on the vanilla fluent-bit package from nixpkgs.  If the
	# upstream Google fork ever becomes necessary (for the Google Cloud output
	# plugin), we can replace this with a custom build that points to the
	# `subagents/fluent-bit` directory inside the Ops Agent repository.
	fluent-bit = pkgs.fluent-bit;

	# Metrics/Tracing sub-agent (OpenTelemetry Collector build used by the Ops Agent).
	# NOTE: the hashes below are placeholders – run `nix flake check` (or build the
	# package) once to obtain the correct values and update them.
	otelopscol = pkgs.buildGoModule rec {
		pname = "otelopscol";
		version = "0.127.0"; # latest tagged version

		src = pkgs.fetchFromGitHub {
			owner = "GoogleCloudPlatform";
			repo = "opentelemetry-operations-collector";
			rev = "v${version}";
			hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
		};

		# Upstream repository uses Go modules, but doesn't vendor deps.
		vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

		subPackages = [ "cmd/otelopscol" ];

		meta = {
			description = "OpenTelemetry Collector distribution shipped with the Google Cloud Ops Agent (sub-agent for metrics & traces)";
			license = lib.licenses.asl20;
			homepage = "https://github.com/GoogleCloudPlatform/opentelemetry-operations-collector";
			mainProgram = "otelopscol";
			platforms = lib.platforms.linux;
			sourceProvenance = [ lib.sourceTypes.fromSource ];
		};
	};
}
