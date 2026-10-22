#!/usr/bin/env python3

import contextlib
import importlib.util
import io
import os
import re
import subprocess
import sys
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest import mock

HELP = """\
opencode-spark starts OpenCode on model spark/muse-glimmer.
Use --lan to force 192.168.4.29 port 4000 with no fallback.
Use --tailnet to force the A record of spark-03b7.tail33327.ts.net.
With neither flag, the LAN address is tried first.
The A record is used only if that probe fails.
Any other arguments are OpenCode arguments.
--no-auto is dropped and is not forwarded.
"""

LAN_DOCUMENT = {
    "enabled_providers": ["spark"],
    "model": "spark/muse-glimmer",
    "small_model": "spark/muse-glimmer",
    "provider": {
        "spark": {
            "npm": "@ai-sdk/openai-compatible",
            "name": "DGX Spark",
            "options": {
                "apiKey": "{env:LITELLM_MASTER_KEY}",
                "baseURL": "http://192.168.4.29:4000/v1",
                "timeout": 600000,
                "headerTimeout": 600000,
                "chunkTimeout": 600000,
            },
            "models": {
                "muse-glimmer": {
                    "name": "Muse Glimmer",
                    "limit": {"context": 131072, "output": 8192},
                }
            },
        }
    },
}

_TYPE_WORDS = frozenset({"string", "integer", "choice", "key=value"})
_FLAG_SECTIONS = frozenset({"FLAGS", "GLOBAL FLAGS"})


def load_module():
    path = Path(__file__).resolve().parent / "opencode-spark"
    loader = SourceFileLoader("opencode_spark", str(path))
    spec = importlib.util.spec_from_file_location(
        "opencode_spark", path, loader=loader
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load opencode-spark")
    module = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True
    spec.loader.exec_module(module)
    return module


def _header(line: str) -> str | None:
    if not line or line[0].isspace():
        return None
    text = line.strip()
    if text and text == text.upper() and any(ch.isalpha() for ch in text):
        return text
    return None


def _section_lines(text: str, names: frozenset[str]) -> list[str]:
    section = None
    found = []
    for line in text.splitlines():
        header = _header(line)
        if header is not None:
            section = header
            continue
        if section in names and line.strip():
            found.append(line.strip())
    return found


def _parse_flag_line(line: str) -> tuple[tuple[str, ...], bool]:
    tokens = line.split()
    names = []
    index = 0
    while index < len(tokens):
        word = tokens[index].rstrip(",")
        if not word.startswith("-"):
            break
        names.append(word)
        index += 1
    takes_value = False
    if names and index < len(tokens):
        kind = tokens[index]
        takes_value = kind in _TYPE_WORDS or (
            len(kind) > 2 and kind.startswith("<") and kind.endswith(">")
        )
    return tuple(names), takes_value


def flags_from_help(text: str, command_flags):
    values: set[str] = set()
    takes_auto = False
    takes_standalone = False
    for line in _section_lines(text, _FLAG_SECTIONS):
        names, takes_value = _parse_flag_line(line)
        if "--auto" in names:
            takes_auto = True
        if "--standalone" in names:
            takes_standalone = True
        if takes_value:
            values.update(names)
    return command_flags(frozenset(values), takes_auto, takes_standalone)


def subcommands_from_help(text: str) -> list[str]:
    found = []
    for line in _section_lines(text, frozenset({"SUBCOMMANDS"})):
        head = re.split(r"\s{2,}", line, maxsplit=1)[0]
        for part in head.split(","):
            name = part.strip()
            if name:
                found.append(name)
    return found


def opencode_help(args: list[str]) -> str:
    env = os.environ.copy()
    env["NO_COLOR"] = "1"
    env["TERM"] = "dumb"
    env.pop("FORCE_COLOR", None)
    proc = subprocess.run(
        ["opencode", *args, "--help"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=20,
        env=env,
    )
    if proc.returncode != 0:
        raise AssertionError(
            f"opencode {' '.join(args)} --help exited {proc.returncode}\n{proc.stderr}"
        )
    return proc.stdout


class OpencodeSparkTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.mod = load_module()
        cls.key = cls.mod.MasterKey("k" * 24)

    def rewritten(self, argv: list[str]):
        invocation = self.mod.parse_invocation(argv, self.mod.FLAG_TABLE)
        self.assertFalse(invocation.help_only)
        return invocation, self.mod.rewrite_args(invocation, self.mod.FLAG_TABLE)

    def test_argv_rows(self) -> None:
        rows = [
            (
                ["-m", "spark/x", "run", "hello"],
                ("--standalone", "--auto", "-m", "spark/x", "run", "hello"),
            ),
            (
                ["run", "-m", "spark/other", "hello"],
                ("run", "--standalone", "--auto", "-m", "spark/other", "hello"),
            ),
            (["models"], ("models", "--standalone")),
            (["mini", "-m", "spark/x"], ("mini", "--standalone", "-m", "spark/x")),
            (
                ["uninstall", "-f", "--dry-run"],
                ("uninstall", "-f", "--dry-run"),
            ),
            (["--no-auto"], ("--standalone",)),
            (["run", "--no-auto", "hello"], ("run", "--standalone", "hello")),
            (["models", "--no-auto"], ("models", "--standalone")),
            (["--auto"], ("--standalone", "--auto")),
            (
                ["run", "--auto", "hello"],
                ("run", "--standalone", "--auto", "hello"),
            ),
            (["models", "--auto"], ("models", "--standalone", "--auto")),
            (["--no-auto", "--auto"], ("--standalone", "--auto")),
            (
                ["run", "--no-auto", "--auto", "hello"],
                ("run", "--standalone", "--auto", "hello"),
            ),
            (["upgrade", "-m", "curl"], ("upgrade", "-m", "curl")),
            (
                ["--prompt", "run", "models"],
                ("--prompt", "run", "models", "--standalone"),
            ),
            (
                ["/tmp", "run", "hello"],
                ("--standalone", "--auto", "/tmp", "run", "hello"),
            ),
            (["--lan", "run", "hello"], ("run", "--standalone", "--auto", "hello")),
            (["--tailnet", "models"], ("models", "--standalone")),
            (["debug", "config"], ("debug", "config")),
            (
                ["run", "--server", "http://127.0.0.1:1", "hello"],
                ("run", "--auto", "--server", "http://127.0.0.1:1", "hello"),
            ),
            (["uninstall", "-f", "--no-auto"], ("uninstall", "-f")),
            (
                ["run", "-f", "--no-auto", "hello"],
                ("run", "--standalone", "--auto", "-f", "--no-auto", "hello"),
            ),
            (["-m", "--no-auto", "hello"], ("--standalone", "-m", "hello")),
        ]
        for argv, expected in rows:
            with self.subTest(argv=argv):
                _invocation, args = self.rewritten(argv)
                self.assertEqual(args, expected)

    def test_route_choice_and_both_flags(self) -> None:
        lan, _args = self.rewritten(["--lan", "run", "hello"])
        self.assertIsInstance(lan.choice, self.mod.ForcedRoute)
        self.assertIs(lan.choice.which, self.mod.Force.LAN)
        tailnet, _args = self.rewritten(["--tailnet", "models"])
        self.assertIsInstance(tailnet.choice, self.mod.ForcedRoute)
        self.assertIs(tailnet.choice.which, self.mod.Force.TAILNET)
        auto, _args = self.rewritten(["run", "hello"])
        self.assertIsInstance(auto.choice, self.mod.AutoRoute)
        for argv in (
            ["--lan", "--tailnet"],
            ["--tailnet", "--lan"],
            ["run", "--lan", "x", "--tailnet"],
        ):
            with self.subTest(argv=argv):
                with self.assertRaises(self.mod.UsageError):
                    self.mod.parse_invocation(argv, self.mod.FLAG_TABLE)

    def test_run_help_is_a_launch_and_lone_help_is_not(self) -> None:
        for argv in (["--help"], ["-h"]):
            invocation = self.mod.parse_invocation(argv, self.mod.FLAG_TABLE)
            self.assertTrue(invocation.help_only)
        invocation, args = self.rewritten(["run", "--help"])
        self.assertFalse(invocation.help_only)
        self.assertEqual(args, ("run", "--standalone", "--auto", "--help"))
        stdout = io.StringIO()
        stderr = io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            self.mod.main(["--help"])
        self.assertEqual(stdout.getvalue(), HELP)
        self.assertEqual(stderr.getvalue(), "")

    def test_both_flags_exit_before_the_key(self) -> None:
        def blocked(*_args, **_kwargs):
            raise AssertionError("pass-cli, dns, or opencode ran")

        stderr = io.StringIO()
        with (
            mock.patch.object(self.mod.subprocess, "run", blocked),
            mock.patch.object(self.mod.os, "execvpe", blocked),
            mock.patch.object(self.mod.socket, "getaddrinfo", blocked),
            contextlib.redirect_stderr(stderr),
        ):
            with self.assertRaises(SystemExit) as caught:
                self.mod.main(["--tailnet", "--lan", "models"])
        self.assertEqual(caught.exception.code, 2)
        self.assertEqual(
            stderr.getvalue(),
            "opencode-spark: pass either --lan or --tailnet, not both\n",
        )

    def test_names_stay_apart(self) -> None:
        with self.assertRaises(ValueError):
            self.mod.Ipv4.parse(self.mod.LAB.tailnet.host)
        with self.assertRaises(ValueError):
            self.mod.Ipv4.parse("192.168.4.29:4000")
        with self.assertRaises(ValueError):
            self.mod.TailnetName(self.mod.LAB.lan.ip.text())
        with self.assertRaises(TypeError):
            self.mod.HttpOrigin(self.mod.LAB.tailnet)
        self.assertEqual(self.mod.LAB.lan.base_url(), "http://192.168.4.29:4000/v1")

    def test_master_key_redacts_itself(self) -> None:
        secret = "SENTINEL_KEY_SHOULD_NOT_LEAK"
        key = self.mod.MasterKey(secret)
        self.assertEqual(str(key), "MasterKey(redacted)")
        self.assertEqual(repr(key), "MasterKey(redacted)")
        self.assertNotIn(secret, repr([key]))
        self.assertEqual(key.reveal(), secret)

    def _fake_pass(self, stdout: bytes, stderr: bytes, code: int):
        def run(args, **kwargs):
            self.assertFalse(kwargs["shell"])
            self.assertNotIn("PROTON_PASS_ACCOUNT", kwargs["env"])
            self.assertEqual(
                args[1:],
                [
                    "item",
                    "view",
                    "--vault-name",
                    "Hermes",
                    "--item-title",
                    "LITELLM_MASTER_KEY",
                    "--field",
                    "secret",
                ],
            )
            return subprocess.CompletedProcess(args, code, stdout=stdout, stderr=stderr)

        return run

    def test_read_master_key_strips_breaks_and_hides_the_value(self) -> None:
        secret = "k" * 24
        env = {"PATH": "/usr/bin", "PROTON_PASS_ACCOUNT": "drop-me"}
        with (
            mock.patch.dict(self.mod.os.environ, env, clear=True),
            mock.patch.object(self.mod.shutil, "which", return_value="/usr/bin/pass-cli"),
            mock.patch.object(
                self.mod.subprocess,
                "run",
                self._fake_pass((secret + "\r\n").encode(), b"", 0),
            ),
        ):
            key = self.mod.read_master_key(self.mod.LAB)
        self.assertEqual(key.reveal(), secret)
        rejected = secret + " "
        with (
            mock.patch.dict(self.mod.os.environ, env, clear=True),
            mock.patch.object(self.mod.shutil, "which", return_value="/usr/bin/pass-cli"),
            mock.patch.object(
                self.mod.subprocess,
                "run",
                self._fake_pass((rejected + "\n").encode(), b"logged out\n", 0),
            ),
        ):
            with self.assertRaises(self.mod.KeyRejected) as caught:
                self.mod.read_master_key(self.mod.LAB)
        self.assertNotIn(secret, str(caught.exception))
        self.assertNotIn(secret, caught.exception.detail)
        leaked = b"supersecretvalue1234567890\n"
        with (
            mock.patch.dict(self.mod.os.environ, env, clear=True),
            mock.patch.object(self.mod.shutil, "which", return_value="/usr/bin/pass-cli"),
            mock.patch.object(
                self.mod.subprocess,
                "run",
                self._fake_pass(leaked, b"warning has the value too\n", 1),
            ),
        ):
            with self.assertRaises(self.mod.KeyRejected) as caught:
                self.mod.read_master_key(self.mod.LAB)
        self.assertEqual(caught.exception.detail, "")
        self.assertNotIn("supersecretvalue1234567890", str(caught.exception))
        self.assertNotIn("supersecretvalue1234567890", caught.exception.detail)
        with (
            mock.patch.dict(self.mod.os.environ, env, clear=True),
            mock.patch.object(self.mod.shutil, "which", return_value="/usr/bin/pass-cli"),
            mock.patch.object(
                self.mod.subprocess,
                "run",
                self._fake_pass(b"\n", b"not logged in\n", 1),
            ),
        ):
            with self.assertRaises(self.mod.KeyRejected) as caught:
                self.mod.read_master_key(self.mod.LAB)
        self.assertEqual(caught.exception.detail, "not logged in\n")

    def test_launch_origin_routes(self) -> None:
        mod = self.mod
        lan_ip = mod.LAB.lan.ip.text()
        tail_ip = "100.87.165.22"

        def hit_lan(origin, _key, model_id, timeout):
            self.assertEqual(origin.ip.text(), lan_ip)
            self.assertEqual(model_id, "muse-glimmer")
            self.assertEqual(timeout, 1.0)
            return mod.ProbeHit(origin)

        def no_dns(_name):
            raise AssertionError("resolved")

        origin = mod.launch_origin(mod.AutoRoute(), mod.LAB, self.key, hit_lan, no_dns)
        self.assertEqual(origin, mod.LAB.lan)
        origin = mod.launch_origin(
            mod.ForcedRoute(mod.Force.LAN), mod.LAB, self.key, hit_lan, no_dns
        )
        self.assertEqual(origin, mod.LAB.lan)

        def miss_lan(origin, _key, _model_id, _timeout):
            self.assertEqual(origin.ip.text(), lan_ip)
            return mod.ProbeMiss(origin.ip.text(), mod.FailReason.TIMEOUT, None)

        with self.assertRaises(mod.RouteError) as caught:
            mod.launch_origin(
                mod.ForcedRoute(mod.Force.LAN), mod.LAB, self.key, miss_lan, no_dns
            )
        self.assertEqual(
            mod.format_route_failure(caught.exception.misses),
            "opencode-spark: route failed: 192.168.4.29:4000 timeout",
        )

        probed = []

        def tail_only(origin, _key, _model_id, _timeout):
            probed.append(origin.ip.text())
            self.assertNotEqual(origin.ip.text(), lan_ip)
            return mod.ProbeHit(origin)

        def resolve_tail(name):
            self.assertEqual(name, mod.LAB.tailnet)
            return mod.Ipv4.parse(tail_ip)

        origin = mod.launch_origin(
            mod.ForcedRoute(mod.Force.TAILNET),
            mod.LAB,
            self.key,
            tail_only,
            resolve_tail,
        )
        self.assertEqual(probed, [tail_ip])
        self.assertEqual(origin.base_url(), "http://100.87.165.22:4000/v1")

        def no_probe(*_args):
            raise AssertionError("probed")

        def dns_fail(_name):
            raise OSError("no such host")

        with self.assertRaises(mod.RouteError) as caught:
            mod.launch_origin(
                mod.ForcedRoute(mod.Force.TAILNET),
                mod.LAB,
                self.key,
                no_probe,
                dns_fail,
            )
        self.assertEqual(
            mod.format_route_failure(caught.exception.misses),
            "opencode-spark: route failed: spark-03b7.tail33327.ts.net dns",
        )

        seen = []

        def both_miss(origin, _key, _model_id, _timeout):
            seen.append(origin.ip.text())
            if origin.ip.text() == lan_ip:
                return mod.ProbeMiss(origin.ip.text(), mod.FailReason.TIMEOUT, None)
            return mod.ProbeMiss(origin.ip.text(), mod.FailReason.HTTP, 401)

        with self.assertRaises(mod.RouteError) as caught:
            mod.launch_origin(
                mod.AutoRoute(), mod.LAB, self.key, both_miss, resolve_tail
            )
        self.assertEqual(seen, [lan_ip, tail_ip])
        self.assertEqual(
            mod.format_route_failure(caught.exception.misses),
            "opencode-spark: route failed: 192.168.4.29:4000 timeout; "
            "100.87.165.22:4000 http 401",
        )

    def test_provider_document_and_child_env(self) -> None:
        import json

        mod = self.mod
        text = mod.provider_document(mod.LAB.lan, mod.LAB)
        self.assertEqual(json.loads(text), LAN_DOCUMENT)
        self.assertNotIn("k" * 24, text)
        tail = mod.HttpOrigin(mod.Ipv4.parse("100.87.165.22"))
        tail_doc = json.loads(mod.provider_document(tail, mod.LAB))
        self.assertEqual(
            tail_doc["provider"]["spark"]["options"]["baseURL"],
            "http://100.87.165.22:4000/v1",
        )
        self.assertEqual(
            tail_doc["provider"]["spark"]["options"]["apiKey"],
            "{env:LITELLM_MASTER_KEY}",
        )
        secret = "SENTINEL_KEY_SHOULD_NOT_LEAK"
        key = mod.MasterKey(secret)
        document = mod.provider_document(mod.LAB.lan, mod.LAB)
        env = mod.child_env(
            {
                "PATH": "/usr/bin",
                "PROTON_PASS_TOKEN": "drop-me",
                "OPENCODE_CONFIG": "/home/david/.config/opencode/opencode.json",
                "LITELLM_MASTER_KEY": "old",
            },
            key,
            document,
        )
        self.assertNotIn("PROTON_PASS_TOKEN", env)
        self.assertEqual(
            env["OPENCODE_CONFIG"], "/home/david/.config/opencode/opencode.json"
        )
        self.assertEqual(env["LITELLM_MASTER_KEY"], secret)
        self.assertEqual(env["OPENCODE_CONFIG_CONTENT"], document)
        self.assertNotIn(secret, env["OPENCODE_CONFIG_CONTENT"])
        self.assertEqual(env["PATH"], "/usr/bin")

    def test_flag_table_matches_opencode_help(self) -> None:
        mod = self.mod
        root = opencode_help([])
        found = {None: flags_from_help(root, mod.CommandFlags)}
        for name in subcommands_from_help(root):
            found[name] = flags_from_help(opencode_help([name]), mod.CommandFlags)
        self.assertNotIn("-f", found["uninstall"].value_flags)
        self.assertIn("-f", found["run"].value_flags)
        self.assertIn("-m", found["run"].value_flags)
        self.assertNotIn("-m", found[None].value_flags)
        self.assertNotIn("--auto", found["run"].value_flags)
        self.assertNotIn("--version", found[None].value_flags)
        self.assertTrue(found[None].takes_auto)
        self.assertTrue(found["run"].takes_auto)
        self.assertFalse(found["models"].takes_auto)
        self.assertFalse(found["mini"].takes_auto)
        self.assertTrue(found[None].takes_standalone)
        self.assertTrue(found["models"].takes_standalone)
        self.assertFalse(found["debug"].takes_standalone)
        self.assertEqual(set(found), set(mod.FLAG_TABLE))
        for key, row in found.items():
            self.assertEqual(mod.FLAG_TABLE[key], row, key)


if __name__ == "__main__":
    unittest.main()
