use std::ffi::c_void;

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
        self.inner.getmember::<_, T>(field).map_err(|err| {
            if self.field_path.is_empty() {
                error!("Failed reading field '{}': {}", field.into_symbol(), err)
            } else {
                error!(
                    "Failed reading field '{}.{}': {}",
                    self.field_path
                        .iter()
                        .map(|v| v.into_symbol().to_string())
                        .collect::<Vec<String>>()
                        .join("."),
                    field.into_symbol(),
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
        let mut func: F = *Box::from_raw(data as _);

        // TODO(cretz): Handle panics/unwind via call_handle_error?
        Box::into_raw(Box::new(func())) as _
    }

    unsafe extern "C" fn anon_unblock<U>(data: *mut c_void)
    where
        U: FnMut(),
    {
        let mut func: U = *Box::from_raw(data as _);

        func();
    }

    let boxed_func = Box::new(func);
    let boxed_unblock = Box::new(unblock);

    unsafe {
        let result = rb_sys::rb_thread_call_without_gvl(
            Some(anon_func::<F, R>),
            Box::into_raw(boxed_func) as *mut _,
            Some(anon_unblock::<U>),
            Box::into_raw(boxed_unblock) as *mut _,
        );

        *Box::from_raw(result as _)
    }
}

pub(crate) struct AsyncCallback {
    queue: BoxValue<Value>,
}

// We trust our usage of this across threads. We would use Opaque but we can't
// box that properly/safely.
unsafe impl Send for AsyncCallback {}
unsafe impl Sync for AsyncCallback {}

impl AsyncCallback {
    pub(crate) fn from_queue(queue: Value) -> Self {
        Self {
            queue: BoxValue::new(queue),
        }
    }

    pub(crate) fn push<V>(&self, value: V) -> Result<(), Error>
    where
        V: IntoValue,
    {
        // self.push_and_continue(value)
        self.queue.funcall(id!("push"), (value,)).map(|_: Value| ())
    }
}
