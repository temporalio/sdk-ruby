# temporalio/contrib/tool_registry

LLM tool-calling primitives for Temporal activities — define tools once, use with
Anthropic or OpenAI.

## Before you start

A Temporal Activity is a function that Temporal monitors and retries automatically on failure. Temporal streams progress between retries via heartbeats — that's the mechanism `run_with_session` uses to resume a crashed LLM conversation mid-turn.

`run_tool_loop` works standalone in any function — no Temporal server needed. Add `AgenticSession` only when you need crash-safe resume inside a Temporal activity.

`AgenticSession` requires a running Temporal worker — it reads and writes heartbeat state from the active activity context. Use `run_tool_loop` standalone for scripts, one-off jobs, or any code that runs outside a Temporal worker.

New to Temporal? → https://docs.temporal.io/develop

**Python or TypeScript user?** Those SDKs also ship framework-level integrations (`openai_agents`, `google_adk_agents`, `langgraph`, `@temporalio/ai-sdk`) for teams already using a specific agent framework. ToolRegistry is the equivalent story for direct Anthropic/OpenAI calls, and shares the same API surface across all six Temporal SDKs.

## Install

Add to your `Gemfile`:

```ruby
gem 'temporalio'
```

Install the LLM client gem separately:

```ruby
gem 'anthropic'   # Anthropic
gem 'ruby-openai' # OpenAI
```

## Quickstart

Tool definitions use [JSON Schema](https://json-schema.org/understanding-json-schema/) for `input_schema`. The quickstart uses a single string field; for richer schemas refer to the JSON Schema docs.

```ruby
require 'temporalio/contrib/tool_registry'
require 'temporalio/contrib/tool_registry/providers/anthropic'

include Temporalio::Contrib  # brings ToolRegistry::* into scope

activity :analyze do |prompt|
  issues = []
  registry = ToolRegistry::Registry.new
  registry.register(
    name: 'flag_issue',
    description: 'Flag a problem found in the analysis',
    input_schema: {
      'type' => 'object',
      'properties' => { 'description' => { 'type' => 'string' } },
      'required' => ['description']
    }
  ) do |input|
    issues << input['description']
    'recorded' # this string is sent back to the LLM as the tool result
  end

  provider = ToolRegistry::Providers::AnthropicProvider.new(
    registry,
    'You are a code reviewer. Call flag_issue for each problem you find.',
    api_key: ENV['ANTHROPIC_API_KEY']
  )

  ToolRegistry.run_tool_loop(provider, registry, prompt)
  issues
end
```

### Selecting a model

The default model is `"claude-sonnet-4-6"` (Anthropic) or `"gpt-4o"` (OpenAI). Override with the `model:` keyword:

```ruby
provider = ToolRegistry::Providers::AnthropicProvider.new(
  registry,
  'You are a code reviewer.',
  api_key: ENV['ANTHROPIC_API_KEY'],
  model: 'claude-3-5-sonnet-20241022'
)
```

Model IDs are defined by the provider — see Anthropic or OpenAI docs for current names.

### OpenAI

```ruby
require 'temporalio/contrib/tool_registry/providers/openai'

provider = ToolRegistry::Providers::OpenAIProvider.new(
  registry, 'your system prompt', api_key: ENV['OPENAI_API_KEY'])
ToolRegistry.run_tool_loop(provider, registry, prompt)
```

## Crash-safe agentic sessions

For multi-turn LLM conversations that must survive activity retries, use
`AgenticSession.run_with_session`. It saves conversation history via
`Temporalio::Activity::Context.current.heartbeat` on every turn and restores
it on retry.

```ruby
require 'temporalio/contrib/tool_registry/session'

results = ToolRegistry::AgenticSession.run_with_session do |session|
  registry = ToolRegistry::Registry.new
  registry.register(name: 'flag', description: '...',
                    input_schema: { 'type' => 'object' }) do |input|
    session.add_result(input)  # use add_result, not session.results <<
    'ok' # this string is sent back to the LLM as the tool result
  end

  provider = ToolRegistry::Providers::AnthropicProvider.new(
    registry, 'your system prompt', api_key: ENV['ANTHROPIC_API_KEY'])
  session.run_tool_loop(provider, registry, prompt)
  session.results  # return value of block = return value of run_with_session
end
```

## Testing without an API key

```ruby
require 'temporalio/contrib/tool_registry'
require 'temporalio/contrib/tool_registry/testing'

include Temporalio::Contrib::ToolRegistry  # brings ToolRegistry::* into scope

registry = Registry.new
registry.register(name: 'flag', description: 'd', input_schema: { 'type' => 'object' }) do |_|
  'ok' # this string is sent back to the LLM as the tool result
end

provider = Testing::MockProvider.new(
  Testing::MockResponse.tool_call('flag', { 'description' => 'stale API' }),
  Testing::MockResponse.done('analysis complete')
).with_registry(registry)

msgs = ToolRegistry.run_tool_loop(provider, registry, 'analyze')
assert msgs.length > 2
```

## Integration testing with real providers

To run the integration tests against live Anthropic and OpenAI APIs:

```bash
RUN_INTEGRATION_TESTS=1 \
  ANTHROPIC_API_KEY=sk-ant-... \
  OPENAI_API_KEY=sk-proj-... \
  ruby -I lib -I test test/contrib/tool_registry_test.rb
```

Tests skip automatically when `RUN_INTEGRATION_TESTS` is unset. Real API calls
incur billing — expect a few cents per full test run.

## Storing application results

`session.results` accumulates application-level
results during the tool loop. Elements are serialized to JSON inside each heartbeat
checkpoint — they must be plain maps/dicts with JSON-serializable values. A non-serializable
value raises a non-retryable `ApplicationError` at heartbeat time rather than silently
losing data on the next retry.

### Storing typed results

Convert your domain type to a plain dict at the tool-call site and back after the session:

```ruby
Result = Struct.new(:type, :file, keyword_init: true)

# Inside tool handler:
session.add_result({ 'type' => 'smell', 'file' => 'foo.rb' })

# After session:
results = session.results.map { |h| Result.new(**h.transform_keys(&:to_sym)) }
```

## Per-turn LLM timeout

Individual LLM calls inside the tool loop are unbounded by default. A hung HTTP
connection holds the activity open until Temporal's `ScheduleToCloseTimeout`
fires — potentially many minutes. Set a per-turn timeout on the provider client:

```ruby
provider = ToolRegistry::Providers::AnthropicProvider.new(
  registry,
  'system prompt',
  api_key: ENV['ANTHROPIC_API_KEY'],
  timeout: 30  # seconds
)
```

Recommended timeouts:

| Model type | Recommended |
|---|---|
| Standard (Claude 3.x, GPT-4o) | 30 s |
| Reasoning (o1, o3, extended thinking) | 300 s |

### Activity-level timeout

Set `schedule_to_close_timeout` on the activity options to bound the entire conversation:

```ruby
workflow.execute_activity(
  MyActivities.long_analysis,
  prompt,
  schedule_to_close_timeout: 600  # seconds
)
```

The per-turn client timeout and `schedule_to_close_timeout` are complementary:
- Per-turn timeout fires if one LLM call hangs (protects against a single stuck turn)
- `schedule_to_close_timeout` bounds the entire conversation including all retries (protects against runaway multi-turn loops)

## MCP integration

`Registry.from_mcp_tools` converts a list of MCP tool descriptors into a populated
registry. Handlers default to no-ops that return an empty string; override them with
`register` after construction.

```ruby
# mcp_tools is an array of objects responding to :name, :description, :input_schema.
registry = ToolRegistry::Registry.from_mcp_tools(mcp_tools)

# Override specific handlers before running the loop.
registry.register(name: 'read_file', description: '...', input_schema: { 'type' => 'object' }) do |input|
  read_file(input['path'])
end
```

Each descriptor must respond to `name`, `description`, and `input_schema` (or
`inputSchema` for camelCase MCP objects). `input_schema` should be a Hash containing
a JSON Schema object.
