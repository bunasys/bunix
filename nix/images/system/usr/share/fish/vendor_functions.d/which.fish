# which, for scripts and hands that expect it: this system has no `which`
# command (x86's BuildStream one has BusyBox's), and fish's own type says
# the same.  -P: the file in $PATH only, never a function or a builtin,
# as which does.
function which --description 'Print the full path of commands'
    type -P $argv
end
