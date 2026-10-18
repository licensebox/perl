# Licensebox perl SDK

MIT · 2026 Vijai Kumar · https://meshing.engineer

Native application licensing for Linux. Requires the public Licensebox C v0.3.0 shared library. Set `LICENSEBOX_LIB_DIR` (or `LICENSEBOX_LIBRARY` for runtime FFI bindings), and add that directory to `LD_LIBRARY_PATH` when linking native extensions. The host library retains installation keys, verifies leases, enforces native identity and stores usage locally. Other platforms and browser runtimes are unvalidated.

The client supports lease, require/module check, local status, sign-in, logout, modules, access requests, access links, and usage recording. Stateless derive/native binding and lease verification helpers are included. Close each client explicitly in a finally/ensure block. Trusted clock, machine binding, sign-in and cancellation hooks are callable platform integration points; never source identity from end users. Callbacks must not reenter or close their client. Callback exceptions become `callback_error` after the native call returns. Native-owned JSON is always freed.

`ci/setup.sh` installs dependencies on disposable Ubuntu 24.04 CI runners only. `ci/test.sh` compiles/tests the actual binding and package consumer. `ci/adapter.sh` runs the shared protocol adapter after testing/building. Run `python3 ../protocol/conformance/run.py --adapter "$PWD/ci/adapter.sh"` with the native environment configured. All test credentials and identities are synthetic.

Build the native core using `scripts/install-native.sh`, then set `LICENSEBOX_LIB_DIR="$PWD/.native/lib"` and `LD_LIBRARY_PATH="$LICENSEBOX_LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"`. Supply only administrator-provided trusted Ed25519 public keys.

```perl
use Licensebox;
my $client = Licensebox::Client->new(product=>'my-app',
  keys=>{'product-key'=>$ENV{LICENSEBOX_PUBLIC_KEY}},
  hooks=>{on_sign_in=>sub { my ($url,$code)=@_; show_sign_in($url,$code) }});
my $ok = eval { $client->require_module('core'); 1 };
my $error = $@;
$client->close;
die $error unless $ok;
# Protected work.
```

Build the XS extension with `perl Makefile.PL && make && make install`, with `LICENSEBOX_LIB_DIR` set for linking. Requires Perl 5.20+ and a C compiler. Each client belongs to its creating interpreter; clients are excluded from ithread cloning. `Licensebox::Error->code` preserves protocol errors. Methods: `lease`, `require_module`, `status`, `sign_in`, `logout`, `modules`, `requests`, `request_access`, `access_link`, `record`, `close`. Package helpers: `derive_binding`, `native_binding`, `verify_lease`.

## Optional heartbeat checkpoints

Call `$client->heartbeat('core')` with a module name to force a silent server check. It returns
`{"lease": ..., "online": true}` after contact, or `online: false` only while
an already verified offline lease remains valid. Heartbeat never activates,
transfers a seat or creates an installation key; sign in explicitly first.
Explicit refusals and removed module grants stop access immediately.

Background work remains opt-in. Schedule checkpoints in your application's own
runtime/event loop and stop protected work at the last verified lease's `expires`
time even if a renewal hangs. Use the signed `heartbeat.interval_seconds` when
present (otherwise a 300-second interval is a reasonable default); a failed
contact never extends the signed deadline. This SDK starts no heartbeat threads.
