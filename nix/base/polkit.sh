unpack $src
# Built with meson, with one more step than ../meson.sh has; the
# arguments for UAPI.9's places are as there.  After them, the element's:
# sessions are logind's, passwords PAM's (its rules include system-auth),
# and members of wheel are the administrators.
# polkitd_uid: not the element's.  The number of polkitd's account,
#   written out as every package's is (Fedora's for it): left out,
#   sysusers picks one when an image is made, and the accounts of systemd
#   after it each get another number than they had.
meson setup build --prefix=/usr --bindir=bin --sbindir=bin --libdir=lib/$triplet \
    --libexecdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release \
    --wrap-mode=nodownload \
    -Dsession_tracking=logind -Dauthfw=pam -Dpam_include=system-auth \
    -Dpam_prefix=/usr/lib/pam.d -Dprivileged_group=wheel \
    -Dintrospection=false -Dexamples=false -Dtests=false -Dman=false -Dgtk_doc=false \
    -Dgettext=false -Dpolkitd_uid=114
# polkit's last step of installing is emptied: a build may not make a
# program set-user-id, and it stops there.  What the step does:
#   pkexec, set-user-id: removed below.
#   the helper that checks a password, set-user-id: systemd starts it as
#     root for each request instead (polkit-agent-helper.socket, enabled
#     in the image's preset).
#   /etc/polkit-1/rules.d: polkit's tmpfiles rule makes it on the running
#     system.
echo '# emptied by bunix: nix/base/polkit.sh says why' > meson_post_install.py
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install

# run0 does its job
rm $out/usr/bin/pkexec
