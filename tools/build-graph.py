#!/usr/bin/env python3
"""What a build will rebuild, how long it should take, and its longest chain.

    tools/build-graph.py                      # the release's targets
    tools/build-graph.py base/mesa.bst        # other targets
    BUNIX_BUILD_HOST=otherbox tools/build-graph.py

Asks the build host's BuildStream (through tools/bst-remote.sh, which first
copies this tree there) for every element's state and dependencies, and its
build logs for how long each element's last successful build took.  Prints:

- the elements that are not cached, and the minutes of work they add up to;
- the longest chain among them: no number of machines can finish the build
  faster than that;
- the biggest jobs.

An element with no successful build on the host has no time: it is listed,
and counted as zero.  The host must be idle: copying this tree to it while
`bst build` runs would change the sources under that build.
The host settings are tools/bst-remote.sh's (BUNIX_BUILD_HOST,
BUNIX_BUILD_SSH_KEY, BUNIX_BUILD_SSH_OPTS, BUNIX_BUILD_KEYS).
"""
import graphlib
import os
import re
import subprocess
import sys

RELEASE_TARGETS = ["system/uki.bst", "system/usr.bst", "system/live.bst",
                   "sysext/gcc.bst", "sysext/rust.bst", "sysext/swift.bst",
                   "sysext/devtools.bst", "sysext/desktop.bst"]
BIGGEST_JOBS_SHOWN = 8
PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def ssh_command():
    """ssh to the build host the way tools/bst-remote.sh does."""
    command = ["ssh"]
    if os.environ.get("BUNIX_BUILD_SSH_KEY"):
        command += ["-i", os.environ["BUNIX_BUILD_SSH_KEY"]]
    command += os.environ.get("BUNIX_BUILD_SSH_OPTS", "").split()
    command.append(os.environ.get("BUNIX_BUILD_HOST", "pro13.home.arpa"))
    return command


def host_is_building():
    # ([b]: the pattern must not match the shell running this check)
    check = subprocess.run(ssh_command() + ['pgrep -f "[b]in/bst " > /dev/null'])
    return check.returncode == 0


def read_graph(targets):
    """{name: {"cached": bool, "build": [names], "runtime": [names]}}"""
    # The dependency lists come out as YAML lists, several lines each, so
    # each element's record ends with a marker instead of a newline.
    record_format = "%{name}|%{state}|%{build-deps}|%{runtime-deps}@@"
    output = subprocess.run(
        [os.path.join(PROJECT, "tools/bst-remote.sh"), "show", "--deps", "all",
         "--format", record_format, *targets],
        check=True, capture_output=True, text=True).stdout
    graph = {}
    for record in output.split("@@"):
        if not record.strip():
            continue
        name, state, build_deps, runtime_deps = record.strip().split("|")
        graph[name] = {"cached": state == "cached",
                       "build": re.findall(r"- (\S+\.bst)", build_deps),
                       "runtime": re.findall(r"- (\S+\.bst)", runtime_deps)}
    return graph


def read_build_minutes():
    """{element: minutes its last successful build took}.  A successful
    build log ends with the build's own time:
        [00:34:17] SUCCESS [db13de91] base/ghostty.bst: Build
    and its file name starts with the time it began (...-build.20261106-222042.log),
    so the newest name per element is its last build."""
    listing = subprocess.run(
        ssh_command() + ["cd ~/.cache/buildstream/logs/bunix 2>/dev/null || exit 0; "
                         "grep -H -E 'SUCCESS \\[[0-9a-f]+\\] [^ ]+: Build$' */*-build.*.log"],
        capture_output=True, text=True).stdout
    newest_log = {}
    minutes = {}
    for line in listing.splitlines():
        found = re.match(r"[^/]+/[0-9a-f]+-build\.(\d{8}-\d{6})\.log:"
                         r"\[(\d+):(\d+):(\d+)\] SUCCESS \[[0-9a-f]+\] (\S+): Build$", line)
        if not found:
            continue
        started, hours, mins, secs, element = found.groups()
        is_newer = started > newest_log.get(element, "")
        if is_newer:
            newest_log[element] = started
            minutes[element] = int(hours) * 60 + int(mins) + int(secs) / 60
    return minutes


def staged_for_build(graph, element):
    """What BuildStream must have built before it can build the element: its
    build dependencies and everything they need at run time."""
    staged = set()
    to_visit = list(graph[element]["build"])
    while to_visit:
        dependency = to_visit.pop()
        if dependency in staged:
            continue
        staged.add(dependency)
        to_visit += graph[dependency]["runtime"]
    return staged


def longest_chain(graph, minutes):
    """(minutes, [elements]) of the slowest chain of builds still to do."""
    # Dependencies first, so each element's are done before it is looked at
    dependencies = {name: graph[name]["build"] + graph[name]["runtime"] for name in graph}
    order = graphlib.TopologicalSorter(dependencies).static_order()

    minutes_until_built = {}
    slowest_dependency = {}
    for element in order:
        # a cached element is ready at once, whatever it was built from
        if graph[element]["cached"]:
            minutes_until_built[element] = 0.0
            continue
        waits_for = None
        for dependency in staged_for_build(graph, element):
            if waits_for is None or minutes_until_built[dependency] > minutes_until_built[waits_for]:
                waits_for = dependency
        start = minutes_until_built[waits_for] if waits_for else 0.0
        minutes_until_built[element] = start + minutes.get(element, 0.0)
        slowest_dependency[element] = waits_for

    last = max(minutes_until_built, key=minutes_until_built.get)
    chain = []
    element = last
    while element is not None and not graph[element]["cached"]:
        chain.insert(0, element)
        element = slowest_dependency.get(element)
    return minutes_until_built[last], chain


def main():
    if host_is_building():
        sys.exit("bst is running on the build host; run this when it is idle")
    targets = sys.argv[1:] or RELEASE_TARGETS
    graph = read_graph(targets)
    minutes = read_build_minutes()

    to_build = [name for name in graph if not graph[name]["cached"]]
    never_built = sorted(name for name in to_build if name not in minutes)
    work = sum(minutes.get(name, 0.0) for name in to_build)
    print(f"To build: {len(to_build)} of {len(graph)} elements, about {work:.0f} min of work")
    if never_built:
        print(f"  no successful build on the host, counted as 0: {', '.join(never_built)}")
    if not to_build:
        return

    total, chain = longest_chain(graph, minutes)
    print(f"Longest chain: {total:.0f} min")
    for name in chain:
        print(f"  {minutes.get(name, 0.0):5.1f} min  {name}")

    print("Biggest jobs:")
    biggest = sorted(to_build, key=lambda name: minutes.get(name, 0.0), reverse=True)
    for name in biggest[:BIGGEST_JOBS_SHOWN]:
        print(f"  {minutes.get(name, 0.0):5.1f} min  {name}")


if __name__ == "__main__":
    main()
