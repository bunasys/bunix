unpack $src

# ../cargo.sh's lines that give cargo its crates
mkdir vendor
for crate in $crates; do
    name=$(basename $crate .crate)
    # the store's name is <hash>-<name>-<version>.crate
    name=${name#*-}
    unpack $crate vendor/$name
    checksum=$(sha256sum < $crate)
    echo "{\"files\":{},\"package\":\"${checksum%% *}\"}" > vendor/$name/.cargo-checksum.json
done
export CARGO_HOME=$PWD/cargo-home
mkdir -p $CARGO_HOME
cat > $CARGO_HOME/config.toml <<END
[source.crates-io]
replace-with = "vendored"
[source.vendored]
directory = "$PWD/vendor"
END

# The workspace as one build: its members compile only with the library
# features the others turn on, which a build of greetd alone does not.
# Only greetd is installed: not agreety, its text greeter (the consoles
# on tty2 to tty6 are the fallback).
cargo build --release --frozen -j$jobs --workspace
install -D -m 755 target/release/greetd $out/usr/bin/greetd

# The user greetd runs the greeter as.  Which greeter, and its command,
# is the greeter's choice: /usr/share/greetd/config.toml is dms-greeter's.
install -D -m 644 /dev/stdin $out/usr/lib/sysusers.d/greetd.conf <<'CONF'
u greeter - "greetd greeter" /var/lib/greetd
CONF

# PAM: "greetd" checks the person logging in and opens their session;
# "greetd-greeter" opens the greeter's own, which needs no password (the
# greeter user has none) but a logind session, for the screen and the
# keyboard.  greetd passes a session only PAM's variables: system-login's
# give it PATH (the system's login-environment), without which a program
# that looks commands up itself finds nothing (dms-greeter finds
# niri-session with Go's exec.LookPath).
pam=$out/usr/lib/pam.d
install -D -m 644 /dev/stdin $pam/greetd <<'PAM'
# bunix: a login through greetd (the login screen)
auth      include   system-login
account   include   system-login
password  include   system-login
session   include   system-login
PAM
install -D -m 644 /dev/stdin $pam/greetd-greeter <<'PAM'
# bunix: the greeter's own session (greetd's "greeter" user, no password)
auth      required  pam_permit.so
account   required  pam_permit.so
password  required  pam_deny.so
session   include   system-login
PAM

# The unit, upheld by multi-user.target (docs/desktop.md, "Units in an
# extension").  It takes tty1 from the console shell; tty2 to tty6 keep
# theirs.  The greeter user and its home are made here too: the boot's
# sysusers may run before the extension is merged, and makes no homes.
#
# It must never end up failed: greetd ends whenever the greeter does
# without a login (no GPU it can draw with, a crash), and with systemd's
# default start limit it would be failed within seconds -- tty1 blank for
# good, and the boot not blessed, so that an update rolls back.  So no
# start limit, and a pause between tries; the consoles on tty2 to tty6
# (autovt@) stay for whoever has to look.  The font cache is made before the
# greeter's first start needs it.
units=$out/usr/lib/systemd/system
install -D -m 644 /dev/stdin $units/greetd.service <<'UNIT'
[Unit]
Description=Login screen (greetd)
StartLimitIntervalSec=0
After=systemd-sysext.service systemd-user-sessions.service fontconfig-cache.service
After=console-shell@tty1.service
Conflicts=console-shell@tty1.service

[Service]
ExecStartPre=/usr/bin/systemd-sysusers /usr/lib/sysusers.d/greetd.conf
ExecStartPre=/usr/bin/install -d -m 0750 -o greeter -g greeter /var/lib/greetd
ExecStart=/usr/bin/greetd --config /usr/share/greetd/config.toml
IgnoreSIGPIPE=no
SendSIGHUP=yes
TimeoutStopSec=30s
KeyringMode=shared
Restart=always
RestartSec=3
UNIT
install -D -m 644 /dev/stdin $units/multi-user.target.d/greetd.conf <<'UNIT'
[Unit]
Upholds=greetd.service
UNIT
# Nor a console on tty1 when a person switches there in such a pause:
# logind would start autovt@tty1, which is console-shell@tty1
# (system/usr/lib/systemd/system/autovt@.service), and so stop greetd
# until multi-user.target upholds it again, ending that console.
ln -s /dev/null $units/autovt@tty1.service
