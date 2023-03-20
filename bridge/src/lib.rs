#[macro_use]
extern crate rutie;
extern crate lazy_static;

mod connection;
mod runtime;
mod test_server;
mod worker;

use connection::{Connection, RpcParams};
use runtime::Runtime;
use rutie::{
    AnyException, AnyObject, Array, Boolean, Encoding, Exception, Hash, Integer, Module, NilClass,
    Object, RString, Symbol, Thread, VM, Float,
};
use temporal_client::{ClientOptionsBuilder, TlsConfig, ClientTlsConfig, RetryConfig};
use temporal_sdk_core::Url;
use std::{collections::HashMap, time::Duration};
use temporal_sdk_core_api::telemetry::{Logger, TelemetryOptionsBuilder};
use test_server::{TemporaliteConfig, TestServer, TestServerConfig};
use tokio_util::sync::CancellationToken;
use worker::{Worker, WorkerError, WorkerResult};

const RUNTIME_THREAD_COUNT: u8 = 2;

fn raise_bridge_exception(message: &str) {
    VM::raise_ex(AnyException::new("Temporalio::Bridge::Error", Some(message)));
}

fn wrap_worker_error(e: &WorkerError) -> AnyException {
    let name = match e {
        WorkerError::Shutdown() => "Temporalio::Bridge::Error::WorkerShutdown",
        _ => "Temporalio::Bridge::Error"
    };

    AnyException::new(name, Some(&format!("[{e:?}] {e}")))
}

fn wrap_bytes(bytes: Vec<u8>) -> RString {
    let enc = Encoding::find("ASCII-8BIT").unwrap();
    RString::from_bytes(&bytes, &enc)
}

fn unwrap_bytes(string: RString) -> Vec<u8> {
    // It is important to use the _unchecked conversion, otherwise Rutie
    // will assume incorrect encoding and screw up the encoded proto
    string.to_vec_u8_unchecked()
}

fn to_hash_map(hash: Hash) -> HashMap<String, String> {
    let mut result = HashMap::new();

    hash.each(|k, v| {
        result.insert(
            k.try_convert_to::<RString>().map_err(VM::raise_ex).unwrap().to_string(),
            v.try_convert_to::<RString>().map_err(VM::raise_ex).unwrap().to_string()
        );
    });

    result
}

fn to_vec(array: Array) -> Vec<String> {
    let mut result: Vec<String> = vec![];
    for item in array.into_iter() {
        let string = item.try_convert_to::<RString>().map_err(VM::raise_ex).unwrap().to_string();
        result.push(string);
    }

    result
}

fn worker_result_to_proc_args(result: WorkerResult) -> [AnyObject; 2] {
    let ruby_nil = NilClass::new().to_any_object();
    match result {
        Ok(bytes) => [wrap_bytes(bytes).to_any_object(), ruby_nil],
        Err(e) => [ruby_nil, wrap_worker_error(&e).to_any_object()]
    }
}

fn unwrap_as_optional<T: rutie::VerifiedObject>(object: Result<AnyObject, AnyException>) -> Option<T> {
    let object = object.map_err(VM::raise_ex).unwrap();
    if object.is_nil() {
        None
    } else {
        Some(
            object
                .try_convert_to::<T>()
                .map_err(VM::raise_ex)
                .unwrap()
        )
    }
}

wrappable_struct!(Connection, ConnectionWrapper, CONNECTION_WRAPPER);
wrappable_struct!(Runtime, RuntimeWrapper, RUNTIME_WRAPPER);
wrappable_struct!(Worker, WorkerWrapper, WORKER_WRAPPER);
wrappable_struct!(TestServer, TestServerWrapper, TEST_SERVER_WRAPPER);

class!(TemporalBridge);

methods!(
    TemporalBridge,
    _rtself, // somehow compiler is sure this is unused and insists on the "_"

    fn create_connection(runtime: AnyObject, options: AnyObject) -> AnyObject {
        let runtime = runtime.unwrap();
        let runtime = runtime.get_data(&*RUNTIME_WRAPPER);

        let options = options.map_err(VM::raise_ex).unwrap();

        let url = options.instance_variable_get("@url").try_convert_to::<RString>().map_err(VM::raise_ex).unwrap().to_string();
        let url = Url::try_from(&*url).map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        let tls = unwrap_as_optional::<AnyObject>(Ok(options.instance_variable_get("@tls"))).map(|x| x.to_any_object());
        let tls = tls.map(|tls| {
            let server_root_ca_cert = unwrap_as_optional::<RString>(Ok(tls.instance_variable_get("@server_root_ca_cert"))).map(unwrap_bytes);
            let client_cert = unwrap_as_optional::<RString>(Ok(tls.instance_variable_get("@client_cert"))).map(unwrap_bytes);
            let client_private_key = unwrap_as_optional::<RString>(Ok(tls.instance_variable_get("@client_private_key"))).map(unwrap_bytes);
            let server_name_override = unwrap_as_optional::<RString>(Ok(tls.instance_variable_get("@server_name_override"))).map(|x| x.to_string());

            TlsConfig {
                server_root_ca_cert,
                client_tls_config:
                    if let (Some(client_cert), Some(client_private_key)) = (client_cert, client_private_key) {
                        Some(ClientTlsConfig {
                            client_cert,
                            client_private_key,
                        })
                    } else {
                        None
                    },
                domain: server_name_override,
            }
        });

        let client_version = options.instance_variable_get("@client_version").try_convert_to::<RString>().map_err(VM::raise_ex).unwrap().to_string();
        let identity = options.instance_variable_get("@identity").try_convert_to::<RString>().map_err(VM::raise_ex).unwrap().to_string();
        let headers = unwrap_as_optional::<Hash>(Ok(options.instance_variable_get("@metadata"))).map(to_hash_map);

        let retry_config = unwrap_as_optional::<AnyObject>(Ok(options.instance_variable_get("@retry_config"))).map(|x| x.to_any_object());
        let retry_config = retry_config.map(|config| {
            let initial_interval = Duration::from_millis(config.instance_variable_get("@initial_interval_millis").try_convert_to::<Integer>().map_err(VM::raise_ex).unwrap().to_u64());
            let randomization_factor = config.instance_variable_get("@randomization_factor").try_convert_to::<Float>().map_err(VM::raise_ex).unwrap().to_f64();
            let multiplier = config.instance_variable_get("@multiplier").try_convert_to::<Float>().map_err(VM::raise_ex).unwrap().to_f64();
            let max_interval = Duration::from_millis(config.instance_variable_get("@max_interval_millis").try_convert_to::<Integer>().map_err(VM::raise_ex).unwrap().to_u64());
            let max_elapsed_time = unwrap_as_optional::<Integer>(Ok(options.instance_variable_get("@max_elapsed_time_millis"))).map(|x| Duration::from_millis(x.to_u64()));
            let max_retries = config.instance_variable_get("@max_retries").try_convert_to::<Integer>().map_err(VM::raise_ex).unwrap().to_u64();

            RetryConfig {
                initial_interval,
                randomization_factor,
                multiplier,
                max_interval,
                max_elapsed_time: max_elapsed_time,
                max_retries: max_retries as usize,
            }
        });

        let mut options = ClientOptionsBuilder::default();
        options.identity(identity)
            .target_url(url)
            .client_name("temporal-ruby".to_string())
            .client_version(client_version)
            .retry_config(retry_config.map_or(RetryConfig::default(), |c| c.into()));
        if let Some(tls_cfg) = tls {
            options.tls_cfg(tls_cfg);
        }

        let options = options.build().map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();
        let result = Thread::call_without_gvl(move || {
            Connection::connect(runtime.tokio_runtime.clone(), options.clone(), headers.clone())
        }, Some(|| {}));

        let connection = result.map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        Module::from_existing("Temporalio")
            .get_nested_module("Bridge")
            .get_nested_class("Connection")
            .wrap_data(connection, &*CONNECTION_WRAPPER)
    }

    fn call_rpc(rpc: Symbol, service: Symbol, request: RString, metadata: Hash, timeout: Integer) -> RString {
        let rpc = rpc.map_err(VM::raise_ex).unwrap().to_string();
        let service = service.map_err(VM::raise_ex).unwrap().to_string();
        let request = unwrap_bytes(request.map_err(VM::raise_ex).unwrap());
        let metadata = to_hash_map(metadata.map_err(VM::raise_ex).unwrap());
        let timeout = timeout.map_or(None, |v| Some(v.to_u64()));
        let token = CancellationToken::new();

        let result = Thread::call_without_gvl(|| {
            let connection = _rtself.get_data_mut(&*CONNECTION_WRAPPER);
            let params = RpcParams {
                rpc: rpc.clone(),
                service: service.clone(),
                request: request.clone(),
                metadata: metadata.clone(),
                timeout_millis: timeout
            };
            connection.call(params, token.clone())
        }, Some(|| { token.cancel() }));

        let response = result.map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        wrap_bytes(response)
    }

    fn init_runtime() -> AnyObject {
        let telemetry_options = TelemetryOptionsBuilder::default()
            .logging(Logger::Console { filter: "temporal_sdk_core=DEBUG".to_string() })
            .build()
            .map_err(|e| raise_bridge_exception(&e.to_string()))
            .unwrap();

        let runtime = Runtime::new(RUNTIME_THREAD_COUNT, telemetry_options);

        Module::from_existing("Temporalio")
            .get_nested_module("Bridge")
            .get_nested_class("Runtime")
            .wrap_data(runtime, &*RUNTIME_WRAPPER)
    }

    fn run_callback_loop() -> NilClass {
        let runtime = _rtself.get_data_mut(&*RUNTIME_WRAPPER);
        runtime.run_callback_loop();

        NilClass::new()
    }

    fn create_worker(runtime: AnyObject, connection: AnyObject, namespace: RString, task_queue: RString, max_cached_workflows: Integer, no_remote_activity: Boolean) -> AnyObject {
        let namespace = namespace.map_err(VM::raise_ex).unwrap().to_string();
        let task_queue = task_queue.map_err(VM::raise_ex).unwrap().to_string();
        let max_cached_workflows = max_cached_workflows.map_err(VM::raise_ex).unwrap().to_u32();
        let no_remote_activity = no_remote_activity.map_err(VM::raise_ex).unwrap().to_bool();
        let runtime = runtime.unwrap();
        let runtime = runtime.get_data(&*RUNTIME_WRAPPER);
        let connection = connection.unwrap();
        let connection = connection.get_data(&*CONNECTION_WRAPPER);
        let worker = Worker::new(runtime, &connection.client, &namespace, &task_queue, max_cached_workflows, no_remote_activity);

        Module::from_existing("Temporalio")
            .get_nested_module("Bridge")
            .get_nested_class("Worker")
            .wrap_data(worker.unwrap(), &*WORKER_WRAPPER)
    }

    fn worker_poll_activity_task() -> NilClass {
        if !VM::is_block_given() {
            panic!("Called #poll_activity_task without a block");
        }

        let ruby_callback = VM::block_proc();
        let callback = move |result: WorkerResult| {
            ruby_callback.call(&worker_result_to_proc_args(result));
        };

        let worker = _rtself.get_data_mut(&*WORKER_WRAPPER);
        let result = worker.poll_activity_task(callback);

        result.map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        NilClass::new()
    }

    fn worker_complete_activity_task(proto: RString) -> NilClass {
        if !VM::is_block_given() {
            panic!("Called #worker_complete_activity_task without a block");
        }

        let bytes = unwrap_bytes(proto.map_err(VM::raise_ex).unwrap());
        let ruby_callback = VM::block_proc();
        let callback = move |result: WorkerResult| {
            ruby_callback.call(&worker_result_to_proc_args(result));
        };

        let worker = _rtself.get_data_mut(&*WORKER_WRAPPER);
        let result = worker.complete_activity_task(bytes, callback);

        result.map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        NilClass::new()
    }

    fn worker_record_activity_heartbeat(proto: RString) -> NilClass {
        let bytes = unwrap_bytes(proto.map_err(VM::raise_ex).unwrap());
        let worker = _rtself.get_data_mut(&*WORKER_WRAPPER);

        let result = worker.record_activity_heartbeat(bytes);

        result.map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        NilClass::new()
    }

    fn worker_poll_workflow_activation() -> NilClass {
        if !VM::is_block_given() {
            panic!("Called #poll_workflow_activation without a block");
        }

        let ruby_callback = VM::block_proc();
        let callback = move |result: WorkerResult| {
            ruby_callback.call(&worker_result_to_proc_args(result));
        };

        let worker = _rtself.get_data_mut(&*WORKER_WRAPPER);
        let result = worker.poll_workflow_activation(callback);

        result.map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        NilClass::new()
    }

    fn worker_complete_workflow_activation(proto: RString) -> NilClass {
        if !VM::is_block_given() {
            panic!("Called #worker_complete_workflow_activation without a block");
        }

        let bytes = unwrap_bytes(proto.map_err(VM::raise_ex).unwrap());
        let ruby_callback = VM::block_proc();
        let callback = move |result: WorkerResult| {
            ruby_callback.call(&worker_result_to_proc_args(result));
        };

        let worker = _rtself.get_data_mut(&*WORKER_WRAPPER);
        let result = worker.complete_workflow_activation(bytes, callback);

        result.map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        NilClass::new()
    }

    fn worker_initiate_shutdown() -> NilClass {
        let worker = _rtself.get_data_mut(&*WORKER_WRAPPER);
        worker.initiate_shutdown().map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        NilClass::new()
    }

    fn worker_finalize_shutdown() -> NilClass {
        let worker = _rtself.get_data_mut(&*WORKER_WRAPPER);
        worker.finalize_shutdown().map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        NilClass::new()
    }

    fn start_test_server(
        runtime: AnyObject,
        existing_path: AnyObject,
        sdk_name: RString,
        sdk_version: RString,
        download_version: RString,
        download_dir: AnyObject,
        port: AnyObject,
        extra_args: Array
    ) -> AnyObject {
        let runtime = runtime.unwrap();
        let runtime = runtime.get_data(&*RUNTIME_WRAPPER);

        let existing_path = unwrap_as_optional::<RString>(existing_path).map(|v| v.to_string());
        let sdk_name = sdk_name.map_err(VM::raise_ex).unwrap().to_string();
        let sdk_version = sdk_version.map_err(VM::raise_ex).unwrap().to_string();
        let download_version = download_version.map_err(VM::raise_ex).unwrap().to_string();
        let download_dir = unwrap_as_optional::<RString>(download_dir).map(|v| v.to_string());
        let port = unwrap_as_optional::<Integer>(port).map(|v| u16::try_from(v.to_u32()).unwrap());
        let extra_args = to_vec(extra_args.map_err(VM::raise_ex).unwrap());

        let test_server = TestServer::start(
            runtime,
            TestServerConfig {
                existing_path,
                sdk_name,
                sdk_version,
                download_version,
                download_dir,
                port,
                extra_args,
            }
        ).map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        Module::from_existing("Temporalio")
            .get_nested_module("Bridge")
            .get_nested_class("TestServer")
            .wrap_data(test_server, &*TEST_SERVER_WRAPPER)
    }

    fn start_temporalite_server(
        runtime: AnyObject,
        existing_path: AnyObject,
        sdk_name: RString,
        sdk_version: RString,
        download_version: RString,
        download_dir: AnyObject,
        namespace: RString,
        ip: RString,
        port: AnyObject,
        database_filename: AnyObject,
        ui: Boolean,
        log_format: RString,
        log_level: RString,
        extra_args: Array
    ) -> AnyObject {
        let runtime = runtime.unwrap();
        let runtime = runtime.get_data(&*RUNTIME_WRAPPER);

        let existing_path = unwrap_as_optional::<RString>(existing_path).map(|v| v.to_string());
        let sdk_name = sdk_name.map_err(VM::raise_ex).unwrap().to_string();
        let sdk_version = sdk_version.map_err(VM::raise_ex).unwrap().to_string();
        let download_version = download_version.map_err(VM::raise_ex).unwrap().to_string();
        let download_dir = unwrap_as_optional::<RString>(download_dir).map(|v| v.to_string());
        let namespace = namespace.map_err(VM::raise_ex).unwrap().to_string();
        let ip = ip.map_err(VM::raise_ex).unwrap().to_string();
        let port = unwrap_as_optional::<Integer>(port).map(|v| u16::try_from(v.to_u32()).unwrap());
        let database_filename = unwrap_as_optional::<RString>(database_filename).map(|v| v.to_string());
        let ui = ui.map_err(VM::raise_ex).unwrap().to_bool();
        let log_format = log_format.map_err(VM::raise_ex).unwrap().to_string();
        let log_level = log_level.map_err(VM::raise_ex).unwrap().to_string();
        let extra_args = to_vec(extra_args.map_err(VM::raise_ex).unwrap());

        let test_server = TestServer::start_temporalite(
            runtime,
            TemporaliteConfig {
                existing_path,
                sdk_name,
                sdk_version,
                download_version,
                download_dir,
                namespace,
                ip,
                port,
                database_filename,
                ui,
                log_format,
                log_level,
                extra_args,
            }
        ).map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        Module::from_existing("Temporalio")
            .get_nested_module("Bridge")
            .get_nested_class("TestServer")
            .wrap_data(test_server, &*TEST_SERVER_WRAPPER)
    }

    fn test_server_has_test_service() -> Boolean {
        let test_server = _rtself.get_data_mut(&*TEST_SERVER_WRAPPER);

        Boolean::new(test_server.has_test_service())
    }

    fn test_server_target() -> RString {
        let test_server = _rtself.get_data_mut(&*TEST_SERVER_WRAPPER);

        RString::new_utf8(&test_server.target())
    }

    fn test_server_shutdown() -> NilClass {
        let test_server = _rtself.get_data_mut(&*TEST_SERVER_WRAPPER);
        test_server.shutdown().map_err(|e| raise_bridge_exception(&e.to_string())).unwrap();

        NilClass::new()
    }
);

#[no_mangle]
pub extern "C" fn init_bridge() {
    Module::from_existing("Temporalio").get_nested_module("Bridge").define(|module| {
        module.define_nested_class("Runtime", None).define(|klass| {
            klass.def_self("init", init_runtime);
            klass.def("run_callback_loop", run_callback_loop);
        });

        module.define_nested_class("Connection", None).define(|klass| {
            klass.def_self("connect", create_connection);
            klass.def("call", call_rpc);
        });

        module.define_nested_class("Worker", None).define(|klass| {
            klass.def_self("create", create_worker);
            klass.def("poll_activity_task", worker_poll_activity_task);
            klass.def("complete_activity_task", worker_complete_activity_task);
            klass.def("record_activity_heartbeat", worker_record_activity_heartbeat);
            klass.def("poll_workflow_activation", worker_poll_workflow_activation);
            klass.def("complete_workflow_activation", worker_complete_workflow_activation);
            klass.def("initiate_shutdown", worker_initiate_shutdown);
            klass.def("finalize_shutdown", worker_finalize_shutdown);
        });

        module.define_nested_class("TestServer", None).define(|klass| {
            klass.def_self("start", start_test_server);
            klass.def_self("start_temporalite", start_temporalite_server);
            klass.def("has_test_service?", test_server_has_test_service);
            klass.def("target", test_server_target);
            klass.def("shutdown", test_server_shutdown);
        });
    });
}
