# Accounts on a running bunix: run on it, as root, by
#
#   BUNIX_CHECK_SCRIPT=tools/vm-checks/accounts.sh tools/boot-vm.sh disk check
#
# (on a disk, where /etc and /home are as an installed machine has them;
# a system in memory passes it too)
#
# A user is made, given a password, logs in over SSH with a key into a
# session logind knows, is locked out and let in again, and removed; and
# the console goes from root's shell to a login prompt when root gets a
# password.  It changes the machine it runs on: for one that is thrown
# away.
#
# NOT checked: a password typed at the console's login prompt (the
# password's hash is checked by PAM's own helper, not through login).
set -euo pipefail

fail() {
    echo "accounts.sh: FAILED: $*" >&2
    exit 1
}
user=tester
password='correct horse battery'

echo "a user is made with a home of their own and bash"
useradd $user
entry=$(getent passwd $user)
[ "${entry##*:}" = /usr/bin/bash ] || fail "the shell of a new user: $entry"
[ "$(stat -c %a /home/$user)" = 700 ] || fail "the home of a new user is open to others"
[ "$(id -gn $user)" = $user ] || fail "a new user has no group of their own"

echo "a password is kept as a yescrypt hash, and checked"
echo "$user:$password" | chpasswd
hash=$(getent shadow $user | cut -d: -f2)
case $hash in
    '$y$'*) ;;
    *) fail "the password is not kept as a yescrypt hash: ${hash:0:4}..." ;;
esac
# unix_chkpwd is what pam_unix hands a password to: it reads it, with a
# zero byte after it
printf '%s\0' "$password" | unix_chkpwd $user nullok || fail "the right password was refused"
if printf '%s\0' "not the password" | unix_chkpwd $user nullok; then
    fail "a wrong password was taken"
fi

echo "root runs a command as the user"
[ "$(runuser -l $user -c 'id -un')" = $user ] || fail "runuser -l did not run as $user"

echo "the user logs in over SSH with a key, into a session of logind's"
key=$(mktemp -d)/key
ssh-keygen -q -t ed25519 -N '' -f $key
install -d -m 700 -o $user -g $user /home/$user/.ssh
install -m 600 -o $user -g $user $key.pub /home/$user/.ssh/authorized_keys
# -n: nothing of this script's own input is the command's to read
as_user() {
    ssh -n -i $key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR -o BatchMode=yes $user@localhost "$@"
}
uid=$(id -u $user)
# what the login says of itself, a line a fact
session=$(as_user 'echo "runtime=$XDG_RUNTIME_DIR"
    loginctl show-session $XDG_SESSION_ID -p Name -p Remote -p Service
    echo "manager=$(systemctl is-active user@$(id -u).service)"') \
    || fail "$user could not log in over SSH with a key"
said() {
    grep -q -x -F "$1" <<< "$session"
}
said "Name=$user" || fail "logind has no session of $user for the SSH login: $session"
said "Service=sshd" || fail "the session is not sshd's: $session"
said "Remote=yes" || fail "the session is not known as one from elsewhere: $session"
said "runtime=/run/user/$uid" || fail "the session has no directory of its own in /run/user: $session"
said "manager=active" || fail "the manager of the user's own services did not start: $session"

echo "a locked password locks SSH too, and unlocking lets the key in again"
passwd -q -l $user
if as_user true 2> /dev/null; then
    fail "$user logged in over SSH with a locked password"
fi
passwd -q -u $user
as_user true || fail "$user could not log in after the password was unlocked"

echo "the user is removed, with their home"
# Their processes are gone before they are: userdel refuses a user who
# still has one, and the manager of their services takes a moment to end.
# (about twenty seconds)
loginctl terminate-user $user 2> /dev/null || true
for try in $(seq 20); do
    pgrep -u $user > /dev/null || break
    sleep 1
done
userdel -r $user || fail "userdel did not remove $user"
[ ! -e /home/$user ] || fail "the home of $user is still there"

echo "the console: root's shell while root has no password, then a login prompt"
console_unit=$(systemctl list-units --plain --no-legend --state=active 'console-shell@*' | head -n 1 | cut -d' ' -f1)
[ -n "$console_unit" ] || fail "no console has a shell"
program_on_console() {
    ps -o comm= -p "$(systemctl show -p MainPID --value $console_unit)"
}
[ "$(program_on_console)" = bash ] || fail "the console runs $(program_on_console), not root's shell"
echo "root:$password" | chpasswd
systemctl restart $console_unit
# the unit's script takes a moment to become the program (about ten seconds)
for try in $(seq 10); do
    [ "$(program_on_console)" != login ] || break
    sleep 1
done
[ "$(program_on_console)" = login ] || fail "root has a password, and the console runs $(program_on_console)"
# and it stays: a login that ends at once is started again, over and over
login_process=$(systemctl show -p MainPID --value $console_unit)
sleep 2
[ "$(systemctl show -p MainPID --value $console_unit)" = "$login_process" ] \
    || fail "the login prompt on the console does not stay"

echo "accounts.sh: passed"
