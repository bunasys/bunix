# A user's way up to root on a running bunix: run on it, as root, by
#
#   BUNIX_CHECK_SCRIPT=tools/vm-checks/run0.sh tools/boot-vm.sh disk check
#
# run0 asks polkit, and polkit asks a member of wheel for their own
# password.  Two users are made, one of them in wheel; each logs in over
# SSH with a key and types a password at run0's prompt.  It changes the
# machine it runs on: for one that is thrown away.
set -euo pipefail

fail() {
    echo "run0.sh: FAILED: $*" >&2
    exit 1
}
administrator=admin
plain_user=guest
# (without a ' in them: they are typed inside a quoted command, below)
administrator_password='correct horse battery'
plain_user_password='staple of another horse'

echo "polkit answers, and its password check waits to be asked"
[ "$(pkaction | wc -l)" -gt 0 ] || fail "polkit lists no actions"
[ "$(systemctl is-active polkit-agent-helper.socket)" = active ] \
    || fail "polkit-agent-helper.socket is not active: no password can be checked"

key=$(mktemp -d)/key
ssh-keygen -q -t ed25519 -N '' -f $key
make_user() {
    local user=$1 password=$2
    useradd $user
    echo "$user:$password" | chpasswd
    install -d -m 700 -o $user -g $user /home/$user/.ssh
    install -m 600 -o $user -g $user $key.pub /home/$user/.ssh/authorized_keys
}
make_user $administrator "$administrator_password"
make_user $plain_user "$plain_user_password"
# the one difference between the two
usermod -a -G wheel $administrator
# -n: nothing of this script's own input is the command's to read
as_user() {
    local user=$1
    shift
    ssh -n -i $key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR -o BatchMode=yes $user@localhost "$@"
}
# What a user runs to type $1 at run0's prompt, for a command only root
# can do: making $proof, in a directory that is root's to write.  It
# prints what the terminal showed.
#   script: gives run0 a terminal, which is where polkit asks.
#   waiting for the prompt, and a second more: polkit throws away what
#     was typed before it turned the echo off.
#   the pause after typing: holds the terminal open while PAM answers.
proof=/run/made-by-run0
typist=/run/type-at-run0
cat > $typist <<END_OF_TYPIST
#!/usr/bin/bash
terminal=\$(mktemp)
wait_for_prompt() {
    for try in \$(seq 150); do
        ! grep -q 'Password:' \$terminal || return 0
        sleep 0.2
    done
}
(wait_for_prompt; sleep 1; echo "\$1"; sleep 3) \\
    | script -q -f -c 'run0 touch $proof' \$terminal > /dev/null
cat \$terminal
END_OF_TYPIST
chmod 755 $typist
# What follows looks at $shown, and at whether $proof is there.
run0_typing() {
    local user=$1 typed=$2
    rm -f $proof
    shown=$(as_user $user "$typist '$typed'" || true)
}
shown_has() {
    grep -q -F "$1" <<< "$shown"
}

echo "an administrator is asked for a password, not refused outright"
answer=$(as_user $administrator 'run0 --no-ask-password true 2>&1' || true)
case $answer in
    *'requires interactive authentication'*) ;;
    *) fail "run0 without a prompt, for a member of wheel, said: $answer" ;;
esac

echo "with their own password, an administrator's command runs as root"
run0_typing $administrator "$administrator_password"
shown_has 'AUTHENTICATION COMPLETE' || fail "polkit did not take the password of $administrator: $shown"
[ -e $proof ] || fail "run0 did not run a command as root for $administrator"

echo "a wrong password is not enough"
run0_typing $administrator "not the password"
shown_has 'AUTHENTICATION FAILED' || fail "polkit did not turn a wrong password down: $shown"
[ ! -e $proof ] || fail "run0 ran a command as root for a wrong password"

# polkit asks such a user for an administrator's password, so the two
# passwords differ: with the same one, this user would rightly get through
echo "nor is the password of a user who is not in wheel"
run0_typing $plain_user "$plain_user_password"
shown_has "Authenticating as: $administrator" || fail "polkit did not ask $plain_user for the administrator's password: $shown"
shown_has 'AUTHENTICATION FAILED' || fail "polkit did not turn the password of $plain_user down: $shown"
[ ! -e $proof ] || fail "run0 ran a command as root for $plain_user, who is not an administrator"

# The helper that checks passwords listens where every user can reach it.
# One who connects and says nothing must not leave a failed unit behind
# (polkit-agent-helper@.service.d/bunix.conf says why).  Nothing on this
# system opens such a socket and only that, so sshd does, for the user:
# it passes on a connection to a port of this machine, which bash opens
# and closes.
echo "a user who connects to the password helper and says nothing leaves no failed unit"
port=9999
helper_socket=/run/polkit/agent-helper.socket
ssh -n -N -i $key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR -o BatchMode=yes -o ExitOnForwardFailure=yes \
    -L 127.0.0.1:$port:$helper_socket $plain_user@localhost &
forward=$!
sleep 2
exec 3<> /dev/tcp/127.0.0.1/$port || fail "no connection to the password helper through sshd"
exec 3>&-
sleep 3
kill $forward
# that the helper was started, and failed: without it, nothing was tried
helper_log=$(journalctl -b --no-pager -o cat -u 'polkit-agent-helper@*')
grep -q 'status=1/FAILURE' <<< "$helper_log" || fail "the silent connection did not reach the helper: $helper_log"
failed=$(systemctl list-units --failed --plain --no-legend 'polkit-agent-helper@*')
[ -z "$failed" ] || fail "the password helper left failed units: $failed"

echo "run0.sh: passed"
