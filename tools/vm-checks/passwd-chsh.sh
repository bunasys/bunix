# What a user changes of their own account on a running bunix, without
# root: run on it, as root, by
#
#   BUNIX_CHECK_SCRIPT=tools/vm-checks/passwd-chsh.sh tools/boot-vm.sh disk check
#
# passwd and chsh write files only root may write, and so are
# set-user-id: the only programs that are (images/system.nix).  On a
# disk and in memory the list reaches the system by two ways
# (images/image.sh), so this is for both: with and without `disk`.  A user
# logs in over SSH with a key, changes their password and their shell,
# each after typing their password, and is refused what is not theirs
# to change.  It changes the machine it runs on: for one that is thrown
# away.
set -euo pipefail

fail() {
    echo "passwd-chsh.sh: FAILED: $*" >&2
    exit 1
}
user=tester
other_user=bystander
# (without a ' in them: they are typed inside a quoted command, below)
first_password='correct horse battery'
second_password='staple of another mule'

echo "passwd and chsh are set-user-id, and nothing else is"
privileged=$(find /usr -type f -perm /6000 | sort | tr '\n' ' ')
[ "$privileged" = "/usr/bin/chsh /usr/bin/passwd " ] || fail "set-user-id or set-group-id: $privileged"

key=$(mktemp -d)/key
ssh-keygen -q -t ed25519 -N '' -f $key
for name in $user $other_user; do
    useradd $name
    echo "$name:$first_password" | chpasswd
done
install -d -m 700 -o $user -g $user /home/$user/.ssh
install -m 600 -o $user -g $user $key.pub /home/$user/.ssh/authorized_keys
# -n: nothing of this script's own input is the command's to read
as_user() {
    ssh -n -i $key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR -o BatchMode=yes $user@localhost "$@"
}
# What the user runs to answer a command that asks for passwords: $1 is
# the command, the rest what to type at each prompt, in order.  It prints
# what the terminal showed, and after it how the command ended.
#   script: gives the command a terminal, which is where PAM asks.
#   waiting for each prompt, and a second more: what is typed before the
#     echo is turned off is thrown away.  A command that is refused asks
#     less often than it is answered: the wait is over when it has ended.
typist=/run/type-at-prompts
cat > $typist <<'END_OF_TYPIST'
#!/usr/bin/bash
command=$1
shift
terminal=$(mktemp)
# $1: how many prompts the terminal is to have shown
wait_for_prompt() {
    local try prompts_shown
    for try in $(seq 150); do
        prompts_shown=$(grep -o 'assword:' $terminal | wc -l)
        [ $prompts_shown -lt $1 ] || return 0
        ! grep -q 'the command ended' $terminal || return 0
        sleep 0.2
    done
}
type_answers() {
    local answer prompt=0
    for answer in "$@"; do
        prompt=$((prompt + 1))
        wait_for_prompt $prompt
        sleep 1
        echo "$answer"
    done
    # the terminal stays open until PAM has answered the last one
    wait_for_prompt $((prompt + 1))
}
# script hands its command to the user's shell, which may be fish: bash
# is given it in a file, and says how it ended
command_file=$(mktemp)
printf '%s\necho "the command ended: $?"\n' "$command" > $command_file
type_answers "$@" | script -q -f -c "/usr/bin/bash $command_file" $terminal > /dev/null
cat $terminal
END_OF_TYPIST
chmod 755 $typist
# What follows looks at $shown as well as at the account: a refusal is
# one only if the command ran and failed.  No change is also what a login
# that failed leaves.
answer_prompts() {
    shown=$(as_user "$typist $*" || true)
}
succeeded() {
    grep -q 'the command ended: 0' <<< "$shown"
}
was_refused() {
    grep -q 'the command ended: [1-9]' <<< "$shown"
}
password_hash() {
    getent shadow $1 | cut -d: -f2
}
shell_of() {
    getent passwd $1 | cut -d: -f7
}
# unix_chkpwd is what pam_unix hands a password to: it reads it, with a
# zero byte after it
password_is() {
    printf '%s\0' "$2" | unix_chkpwd $1 nullok
}

echo "a user changes their own password, typing the old one first"
answer_prompts "passwd '$first_password' '$second_password' '$second_password'"
succeeded || fail "passwd failed for $user: $shown"
password_is $user "$second_password" || fail "passwd did not change the password of $user: $shown"

echo "not without the old one"
hash_before=$(password_hash $user)
answer_prompts "passwd 'not the password' 'a third password' 'a third password'"
was_refused || fail "passwd did not refuse a wrong old password: $shown"
[ "$(password_hash $user)" = "$hash_before" ] || fail "passwd changed a password for a wrong old one: $shown"

echo "and not another user's"
hash_before=$(password_hash $other_user)
answer_prompts "'passwd $other_user' '$second_password' 'a third password' 'a third password'"
was_refused || fail "passwd did not refuse $user the password of $other_user: $shown"
[ "$(password_hash $other_user)" = "$hash_before" ] || fail "$user changed the password of $other_user: $shown"

echo "a user chooses fish as their shell, typing their password, and logs in to it"
[ "$(shell_of $user)" = /usr/bin/bash ] || fail "the shell of a new user: $(shell_of $user)"
answer_prompts "'chsh -s /usr/bin/fish' '$second_password'"
succeeded || fail "chsh failed for $user: $shown"
[ "$(shell_of $user)" = /usr/bin/fish ] || fail "chsh did not make fish the shell of $user: $shown"
# sshd hands the command to the user's shell; only fish has this variable
fish_version=$(as_user 'echo $FISH_VERSION') || fail "$user could not log in with fish as their shell"
[ -n "$fish_version" ] || fail "the shell $user logs in to is not fish"

echo "not without their password"
answer_prompts "'chsh -s /usr/bin/bash' 'not the password'"
was_refused || fail "chsh did not refuse a wrong password: $shown"
[ "$(shell_of $user)" = /usr/bin/fish ] || fail "chsh changed a shell for a wrong password: $shown"

# with the right password: it is the shell that is refused
echo "not to a program that is no shell (/etc/shells)"
answer_prompts "'chsh -s /usr/bin/true' '$second_password'"
was_refused || fail "chsh did not refuse /usr/bin/true: $shown"
grep -q 'not listed' <<< "$shown" || fail "chsh refused /usr/bin/true, and not for /etc/shells: $shown"
[ "$(shell_of $user)" = /usr/bin/fish ] || fail "chsh made /usr/bin/true the shell of $user: $shown"

echo "and not another user's"
answer_prompts "'chsh -s /usr/bin/fish $other_user' '$second_password'"
was_refused || fail "chsh did not refuse $user the shell of $other_user: $shown"
[ "$(shell_of $other_user)" = /usr/bin/bash ] || fail "$user changed the shell of $other_user: $shown"

echo "root changes anyone's, and is asked nothing"
chsh -s /usr/bin/fish $other_user < /dev/null || fail "chsh as root did not change the shell of $other_user"
[ "$(shell_of $other_user)" = /usr/bin/fish ] || fail "the shell of $other_user after root's chsh: $(shell_of $other_user)"

echo "passwd-chsh.sh: passed"
