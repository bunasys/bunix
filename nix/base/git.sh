unpack $src
# Git has no configure step that it needs: what is to be built is said to
# make, and the same to both of its runs.
# INSTALL_SYMLINKS: the built-in commands (git-add, ...) are links to
# git, not copies of it.
git_make() {
    make prefix=/usr gitexecdir=/usr/lib/git-core sysconfdir=/etc CFLAGS="$CFLAGS" \
        USE_LIBPCRE2=1 NO_PERL=1 NO_PYTHON=1 NO_TCLTK=1 NO_GETTEXT=1 NO_RUST=1 INSTALL_SYMLINKS=1 "$@"
}
git_make all
git_make DESTDIR=$out install
