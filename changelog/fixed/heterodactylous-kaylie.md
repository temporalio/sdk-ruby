Core: A workflow task failure reported with the cause `WORKFLOW_TASK_FAILED_CAUSE_EXTERNAL_STORAGE_FAILURE` is now counted on `workflow_task_execution_failed` with `failure_reason="ExternalStorageError"`, matching activity failures with the storage cause. It was previously counted as `WorkflowError`.
Core: Ephemeral dev and test servers now complete the automatic port reservation handshake on Linux and macOS before starting, preventing intermittent address-in-use errors during TCP teardown.
Core: Resource-based worker tuners now read CPU usage and quotas from standard cgroup v1 mounts. Workers on cgroup v1 systems no longer fall back to host CPU usage and admit work based on understated container load.
Core: Preserve queued queries across workflow eviction so requests for the same run are answered instead of silently dropped.
Core: Rejection-only update tasks no longer dispatch local activities resumed from replay before validation, allowing those tasks to remain unrecorded in workflow history.
Core: Preparing a legacy query now remains in replay mode, preventing unrecorded local activity attempts that could execute twice or leave the workflow stuck.
