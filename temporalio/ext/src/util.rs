use std::ffi::c_void;
use std::mem::ManuallyDrop;

use magnus::symbol::IntoSymbol;
use magnus::value::{BoxValue, OpaqueId, ReprValue};
use magnus::{Error, RStruct, TryConvert, Value};
use magnus::{IntoValue, Ruby};

use crate::{error, id};

pub(crate) struct Struct {
    field_path: Vec<OpaqueId>,
    inner: RStruct,
}

impl TryConvert for Struct {
    fn try_convert(val: Value) -> Result<Self, Error> {
        Ok(Self {
            field_path: Vec::new(),
            inner: RStruct::try_convert(val)?,
        })
    }
}

impl Struct {
    pub(crate) fn member<T>(&self, field: OpaqueId) -> Result<T, Error>
    where
        T: TryConvert,
    {
        let ruby = Ruby::get().expect("Ruby missing");
        self.inner.getmember::<_, T>(field).map_err(|err| {
            if self.field_path.is_empty() {
                error!(
                    "Failed reading field '{}': {}",
                    field.into_symbol_with(&ruby),
                    err
                )
            } else {
                error!(
                    "Failed reading field '{}.{}': {}",
                    self.field_path
                        .iter()
                        .map(|v| v.into_symbol_with(&ruby).to_string())
                        .collect::<Vec<String>>()
                        .join("."),
                    field.into_symbol_with(&ruby),
                    err
                )
            }
        })
    }

    pub(crate) fn child(&self, field: OpaqueId) -> Result<Option<Struct>, Error> {
        self.member::<Option<RStruct>>(field).map(|inner| {
            inner.map(|inner| {
                let mut field_path = self.field_path.clone();
                field_path.push(field);
                Struct { field_path, inner }
            })
        })
    }
}

/// Inspired by https://github.com/matsadler/magnus/pull/14 and
/// https://github.com/matsadler/magnus/pull/48 and
/// https://github.com/danielpclark/rutie/blob/master/src/binding/thread.rs and
/// others.
pub(crate) fn without_gvl<F, R, U>(func: F, unblock: U) -> R
where
    F: FnMut() -> R,
    U: FnMut(),
{
    // These extern functions are unsafe because they are callbacks from Ruby C
    // code that unbox data into Rust functions. This is only used within this
    // function and we can trust the boxed-then-unboxed Rust functions live for
    // the life of this function (and Ruby does not use them after that).

    unsafe extern "C" fn anon_func<F, R>(data: *mut c_void) -> *mut c_void
    where
        F: FnMut() -> R,
    {
        let mut func: F = unsafe { *Box::from_raw(data as _) };

        // TODO(cretz): Handle panics/unwind via call_handle_error?
        Box::into_raw(Box::new(func())) as _
    }

    unsafe extern "C" fn anon_unblock<U>(data: *mut c_void)
    where
        U: FnMut(),
    {
        // Borrow rather than take ownership — the caller frees after
        // rb_thread_call_without_gvl returns. This avoids leaking the
        // unblock closure when Ruby never invokes it (the common case).
        let func: &mut U = unsafe { &mut *(data as *mut U) };
        func();
    }

    let boxed_func = Box::new(func);
    let boxed_unblock = Box::new(unblock);
    let unblock_ptr = Box::into_raw(boxed_unblock);

    unsafe {
        let result = rb_sys::rb_thread_call_without_gvl(
            Some(anon_func::<F, R>),
            Box::into_raw(boxed_func) as *mut _,
            Some(anon_unblock::<U>),
            unblock_ptr as *mut _,
        );

        // Free the unblock closure. By the time rb_thread_call_without_gvl
        // returns, anon_unblock (if called at all) has already completed,
        // so this is safe.
        drop(Box::from_raw(unblock_ptr));

        *Box::from_raw(result as _)
    }
}

/// Utility for pushing a result to a queue in an async callback.
pub(crate) struct AsyncCallback {
    queue: SendSyncBoxValue<Value>,
}

impl AsyncCallback {
    pub(crate) fn from_queue(queue: Value) -> Self {
        Self {
            queue: SendSyncBoxValue::new(queue),
        }
    }

    pub(crate) fn push<V>(&self, ruby: &Ruby, value: V) -> Result<(), Error>
    where
        V: IntoValue,
    {
        let queue = self.queue.value(ruby);
        queue.funcall(id!("push"), (value,)).map(|_: Value| ())
    }
}

/// Utility that basically combines Magnus BoxValue with Magnus Opaque. It's a
/// Send/Sync safe Ruby value that prevents GC until dropped and is only
/// accessible from a Ruby thread.
#[derive(Debug)]
pub(crate) struct SendSyncBoxValue<T: ReprValue>(BoxValue<T>);

// We trust our usage of this across threads. We would use Opaque but we can't
// box that properly/safely to ensure it does not get GC'd.
unsafe impl<T: ReprValue> Send for SendSyncBoxValue<T> {}
unsafe impl<T: ReprValue> Sync for SendSyncBoxValue<T> {}

impl<T: ReprValue> SendSyncBoxValue<T> {
    pub fn new(val: T) -> Self {
        Self(BoxValue::new(val))
    }

    pub fn value(&self, _: &Ruby) -> T {
        *self.0
    }
}

/// Like SendSyncBoxValue but safe to drop from any thread. When dropped on a
/// non-Ruby thread (e.g. a Tokio worker), the BoxValue and its GC registration
/// are intentionally leaked instead of calling rb_gc_unregister_address (which
/// would corrupt Ruby's GC data structures). On a Ruby thread, cleanup proceeds
/// normally.
///
/// Use this for metric buffer objects (instruments, attribute sets) where:
/// - The Rust Core SDK may drop Arc references on Tokio threads
/// - The number of unique objects is bounded (small, acceptable leak)
pub(crate) struct ThreadSafeBoxValue<T: ReprValue>(ManuallyDrop<BoxValue<T>>);

unsafe impl<T: ReprValue> Send for ThreadSafeBoxValue<T> {}
unsafe impl<T: ReprValue> Sync for ThreadSafeBoxValue<T> {}

impl<T: ReprValue> ThreadSafeBoxValue<T> {
    pub fn new(val: T) -> Self {
        Self(ManuallyDrop::new(BoxValue::new(val)))
    }

    pub fn value(&self, _: &Ruby) -> T {
        **self.0
    }
}

impl<T: ReprValue> Drop for ThreadSafeBoxValue<T> {
    fn drop(&mut self) {
        if Ruby::get().is_ok() {
            // On a Ruby thread: safe to call rb_gc_unregister_address
            unsafe { ManuallyDrop::drop(&mut self.0); }
        }
        // On a non-Ruby thread: intentionally leak the BoxValue to avoid
        // calling rb_gc_unregister_address from a thread unknown to Ruby's VM
    }
}

impl<T: ReprValue> std::fmt::Debug for ThreadSafeBoxValue<T> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ThreadSafeBoxValue").finish()
    }
}
