set -gx EDITOR nvim

function fish_greeting
    set_color cyan
    echo "bunix -- everything here was compiled from source"
    set_color normal
    echo "  kernel  "(uname -sr)"  ("(systemd-detect-virt)")"
    echo "  systemd "(systemctl --version | head -1 | cut -d" " -f2)"   fish "$version
    echo "  try: networkctl | resolvectl status | curl -I https://example.com"
    echo "       iwctl station wlan0 scan | systemd-analyze blame | journalctl -b"
end
