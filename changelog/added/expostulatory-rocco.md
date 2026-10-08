Core: Child workflow commands, including those submitted through the C bridge, support pinned, auto-upgrade, and one-time worker deployment versioning overrides on Temporal Server 1.32.0 or later. Child-start resolutions distinguish invalid versioning overrides and missing namespaces from other start failures.
Core: External workflow signal and cancellation resolution activations now include the typed server failure cause alongside the existing failure.
Core: Language SDKs can opt in to recording local activity arguments in the local activity marker's `input` detail.
Core: Workflow completion-as-cancelled commands can now carry details for recording on the terminal history event.
Core: Core now supports attaching `EventGroupMarker`s to most workflow commands.
Core: The `temporal_activity_execution_failed` and `temporal_local_activity_execution_failed` worker metrics now carry a `failure_reason` attribute. Each is now split into one time series per reason, which may affect existing dashboards.
Core: Workflow task completions larger than the gRPC request size limit are now paginated automatically when the namespace supports it. Paginated workflow task completions require Temporal Server 1.32.0 or later.
