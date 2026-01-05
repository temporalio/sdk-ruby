use std::collections::HashMap;

use magnus::{Error, RHash, RString, Ruby, class, function, prelude::*, scan_args};
use temporalio_common::envconfig::{
    ClientConfig as CoreClientConfig, ClientConfigCodec,
    ClientConfigProfile as CoreClientConfigProfile, ClientConfigTLS as CoreClientConfigTLS,
    DataSource, LoadClientConfigOptions, LoadClientConfigProfileOptions,
    load_client_config as core_load_client_config,
    load_client_config_profile as core_load_client_config_profile,
};

use crate::{ROOT_MOD, error};

pub fn init(ruby: &Ruby) -> Result<(), Error> {
    let root_mod = ruby.get_inner(&ROOT_MOD);

    let class = root_mod.define_class("EnvConfig", class::object())?;
    class.define_singleton_method("load_client_config", function!(load_client_config, -1))?;
    class.define_singleton_method(
        "load_client_connect_config",
        function!(load_client_connect_config, -1),
    )?;

    Ok(())
}

fn data_source_to_hash(ruby: &Ruby, ds: &DataSource) -> Result<RHash, Error> {
    let hash = RHash::new();
    match ds {
        DataSource::Path(p) => {
            hash.aset(ruby.sym_new("path"), ruby.str_new(p))?;
        }
        DataSource::Data(d) => {
            hash.aset(ruby.sym_new("data"), ruby.str_from_slice(d))?;
        }
    }
    Ok(hash)
}

fn tls_to_hash(ruby: &Ruby, tls: &CoreClientConfigTLS) -> Result<RHash, Error> {
    let hash = RHash::new();
    hash.aset(ruby.sym_new("disabled"), tls.disabled)?;

    if let Some(v) = &tls.client_cert {
        hash.aset(ruby.sym_new("client_cert"), data_source_to_hash(ruby, v)?)?;
    }
    if let Some(v) = &tls.client_key {
        hash.aset(ruby.sym_new("client_key"), data_source_to_hash(ruby, v)?)?;
    }
    if let Some(v) = &tls.server_ca_cert {
        hash.aset(
            ruby.sym_new("server_ca_cert"),
            data_source_to_hash(ruby, v)?,
        )?;
    }
    if let Some(v) = &tls.server_name {
        hash.aset(ruby.sym_new("server_name"), ruby.str_new(v))?;
    }
    hash.aset(
        ruby.sym_new("disable_host_verification"),
        tls.disable_host_verification,
    )?;

    Ok(hash)
}

fn codec_to_hash(ruby: &Ruby, codec: &ClientConfigCodec) -> Result<RHash, Error> {
    let hash = RHash::new();
    if let Some(v) = &codec.endpoint {
        hash.aset(ruby.sym_new("endpoint"), ruby.str_new(v))?;
    }
    if let Some(v) = &codec.auth {
        hash.aset(ruby.sym_new("auth"), ruby.str_new(v))?;
    }
    Ok(hash)
}

fn profile_to_hash(ruby: &Ruby, profile: &CoreClientConfigProfile) -> Result<RHash, Error> {
    let hash = RHash::new();

    if let Some(v) = &profile.address {
        hash.aset(ruby.sym_new("address"), ruby.str_new(v))?;
    }
    if let Some(v) = &profile.namespace {
        hash.aset(ruby.sym_new("namespace"), ruby.str_new(v))?;
    }
    if let Some(v) = &profile.api_key {
        hash.aset(ruby.sym_new("api_key"), ruby.str_new(v))?;
    }
    if let Some(tls) = &profile.tls {
        hash.aset(ruby.sym_new("tls"), tls_to_hash(ruby, tls)?)?;
    }
    if let Some(codec) = &profile.codec {
        hash.aset(ruby.sym_new("codec"), codec_to_hash(ruby, codec)?)?;
    }
    if !profile.grpc_meta.is_empty() {
        let grpc_meta_hash = RHash::new();
        for (k, v) in &profile.grpc_meta {
            grpc_meta_hash.aset(ruby.str_new(k), ruby.str_new(v))?;
        }
        hash.aset(ruby.sym_new("grpc_meta"), grpc_meta_hash)?;
    }

    Ok(hash)
}

fn core_config_to_hash(ruby: &Ruby, core_config: &CoreClientConfig) -> Result<RHash, Error> {
    let profiles_hash = RHash::new();
    for (name, profile) in &core_config.profiles {
        let profile_hash = profile_to_hash(ruby, profile)?;
        profiles_hash.aset(ruby.str_new(name), profile_hash)?;
    }
    Ok(profiles_hash)
}

fn load_client_config_inner(
    ruby: &Ruby,
    config_source: Option<DataSource>,
    config_file_strict: bool,
    env_vars: Option<HashMap<String, String>>,
) -> Result<RHash, Error> {
    let options = LoadClientConfigOptions {
        config_source,
        config_file_strict,
    };
    let core_config = core_load_client_config(options, env_vars.as_ref())
        .map_err(|e| error!("EnvConfig error: {}", e))?;

    core_config_to_hash(ruby, &core_config)
}

fn load_client_connect_config_inner(
    ruby: &Ruby,
    config_source: Option<DataSource>,
    profile: Option<String>,
    disable_file: bool,
    disable_env: bool,
    config_file_strict: bool,
    env_vars: Option<HashMap<String, String>>,
) -> Result<RHash, Error> {
    let options = LoadClientConfigProfileOptions {
        config_source,
        config_file_profile: profile,
        config_file_strict,
        disable_file,
        disable_env,
    };

    let profile = core_load_client_config_profile(options, env_vars.as_ref())
        .map_err(|e| error!("EnvConfig error: {}", e))?;

    profile_to_hash(ruby, &profile)
}

// load_client_config(path: String|nil, data: String|nil, config_file_strict: bool, env_vars: Hash|nil)
fn load_client_config(args: &[magnus::Value]) -> Result<RHash, Error> {
    let ruby = Ruby::get().expect("Not in Ruby thread");
    let args = scan_args::scan_args::<
        (
            Option<String>,
            Option<RString>,
            bool,
            Option<HashMap<String, String>>,
        ),
        (),
        (),
        (),
        (),
        (),
    >(args)?;
    let (path, data, config_file_strict, env_vars) = args.required;

    let config_source = match (path, data) {
        (Some(p), None) => Some(DataSource::Path(p)),
        (None, Some(d)) => {
            let bytes = unsafe { d.as_slice().to_vec() };
            Some(DataSource::Data(bytes))
        }
        (None, None) => None,
        (Some(_), Some(_)) => {
            return Err(error!(
                "Cannot specify both path and data for config source"
            ));
        }
    };

    load_client_config_inner(&ruby, config_source, config_file_strict, env_vars)
}

// load_client_connect_config(profile: String|nil, path: String|nil, data: String|nil, disable_file: bool, disable_env: bool, config_file_strict: bool, env_vars: Hash|nil)
fn load_client_connect_config(args: &[magnus::Value]) -> Result<RHash, Error> {
    let ruby = Ruby::get().expect("Not in Ruby thread");
    let args = scan_args::scan_args::<
        (
            Option<String>,
            Option<String>,
            Option<RString>,
            bool,
            bool,
            bool,
            Option<HashMap<String, String>>,
        ),
        (),
        (),
        (),
        (),
        (),
    >(args)?;
    let (profile, path, data, disable_file, disable_env, config_file_strict, env_vars) =
        args.required;

    let config_source = match (path, data) {
        (Some(p), None) => Some(DataSource::Path(p)),
        (None, Some(d)) => {
            let bytes = unsafe { d.as_slice().to_vec() };
            Some(DataSource::Data(bytes))
        }
        (None, None) => None,
        (Some(_), Some(_)) => {
            return Err(error!(
                "Cannot specify both path and data for config source"
            ));
        }
    };

    load_client_connect_config_inner(
        &ruby,
        config_source,
        profile,
        disable_file,
        disable_env,
        config_file_strict,
        env_vars,
    )
}
