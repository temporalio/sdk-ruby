Added experimental Event Groups support: `Workflow.create_event_group`, `Workflow.with_event_groups`, and `event_groups:` on workflow command APIs. Signal and update handlers get implicit inbound groups.
`Workflow::Info#original_execution_run_id` is the run ID recorded on the workflow execution started event and is preserved across workflow resets.
