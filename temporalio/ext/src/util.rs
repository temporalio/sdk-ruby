use std::ffi::c_void;

use magnus::Ruby;
use magnus::{Error, RStruct, TryConvert, Value};

use crate::error;

pub(crate) struct Struct {
    field_path: Vec<&'static str>,
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
    pub(crate) fn aref<T>(&self, field: &'static str) -> Result<T, Error>
    where
        T: TryConvert,
    {
        self.inner.aref::<_, T>(field).map_err(|err| {
            if self.field_path.is_empty() {
                error!("Failed reading field '{}': {}", field, err)
            } else {
                error!(
                    "Failed reading field '{}.{}': {}",
                    self.field_path.join("."),
                    field,
                    err
                )
            }
        })
    }

    pub(crate) fn child(&self, field: &'static str) -> Result<Option<Struct>, Error> {
        self.aref::<Option<RStruct>>(field).map(|inner| {
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
