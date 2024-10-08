# Ruby Rust Bridge

This is a Ruby extension written in Rust to incorporate https://github.com/temporalio/sdk-core (included as a
submodule). This leverages https://github.com/oxidize-rb/rb-sys and https://github.com/matsadler/magnus.

## Tokio Async to Ruby Async

There is no general accepted way to bridge the gap between async Tokio and async Ruby. It is important not only that
calls to/from Ruby happen with the GVL, but in threads _Ruby_ creates. C extensions cannot reasonably turn a non-Ruby
thread into a Ruby thread.

What the current implementation does is asks the Ruby side to instantiate and run a "command loop". This eats up a
single Ruby thread for the life of the runtime (which is usually the life of the process). This run-command-loop call
unlocks the GVL and waits on a Rust mpsc channel to feed it work. Ignoring shutdown machinations, the work is just a
Ruby callback. When the Rust channel receives a Ruby callback on this Ruby thread, it re-acquires the GVL and runs the
callback. Since this occurs serially for each callback in a single thread the callback is expected to be very fast.

Each thing that needs to do some async Tokio call, calls a helper with two things: the future to spawn in Tokio runtime,
and the callback to handle the results in the Ruby thread. All users of this helper are expected to do basically
everything in the async Tokio function, and do a very simple Ruby block call (or similar) in the callback.

So async calls usually looks like this:

* In Ruby, call method implemented in Rust, e.g.

    ```
    queue = Queue.new
    some_bridge_thing.do_foo(queue)
    queue.pop
    ```

* In Rust, `do_foo` spawns some Tokio async thing and returns
* Once Tokio async thing is completed, in the Ruby-thread callback, Rust side converts that thing to a Ruby thing and
  pushes to the queue

This allows Ruby to remain async if in a Fiber, because Ruby `queue.pop` does not block a thread when in a Fiber
context. The invocation of a queue push with a value is quite cheap in Ruby.

## Argument Passing

For the smallest set of arguments, a simple positional or kwarg is fine. For anything larger, a `Struct` defined on the
Ruby side should be used. Parameters to Ruby functions defined in Rust should have no defaults. We want to make sure we
catch any missing arguments eagerly (e.g. the first test that even uses the struct/args).