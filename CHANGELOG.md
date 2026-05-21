# Changelog

## [Unreleased]

### Added

- 💥 Standalone Activities: activities that execute independently of any workflow.
  ```
	handle = client.start_activity(
		MyActivity,
		'some-arg',
		id: 'my-activity-id',
		task_queue: 'my-task-queue',
		start_to_close_timeout: 60
		)
	result = handle.result   # blocks until the activity completes
  ```