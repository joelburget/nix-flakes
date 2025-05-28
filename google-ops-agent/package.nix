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

	# Logging sub-agent used by the Ops Agent (Google-patched Fluent Bit fork).
	# The Google Cloud Ops Agent ships its own fork of Fluent-Bit that adds the
	# Stackdriver output plugin and a couple of minor patches.  Build that
	# variant so that the `stackdriver` output configured by the agent engine
	# actually exists.
	fluent-bit = pkgs.fluent-bit.overrideAttrs (_: {
		pname   = "fluent-bit-google";
		version = version; # align with Ops Agent tag, e.g. 2.46.1

		# Source lives inside the Ops Agent monorepo – point `sourceRoot`
		# so the build system changes into that directory after unpacking.
		src = opsAgentSrc;
		sourceRoot = "source/subagents/fluent-bit";

		# Disable bundled deps download – rely on Nix inputs only.
		FLB_EMBED_PLUGINS = "yes";

		postPatch = ''
			# make sure CMake can find the bundled google output plugin sources
			substituteInPlace CMakeLists.txt \
				--replace "bundled-out_google_cloud" "bundled-out_google_cloud"
		'';
	});

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
			hash = "sha256-Z5c4ezYHSG7Mx+m3SSq0TTZW5tPwW/X5N9Obq1bNtJ4=";
		};

		# Upstream repository uses Go modules, but doesn't vendor deps.
		vendorHash = "sha256-enHmzau2QS6xj+rDRJDxqdlskRjxSktAdJUChfLTrtY=";

		postPatch = ''
		  # Allow building with the Go version available in this nixpkgs (1.22)
		  substituteInPlace go.mod --replace "go 1.24" "go 1.22"
		'';

		subPackages = [ "otelopscol" ];

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
