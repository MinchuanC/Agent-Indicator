# Agent Indicator

A native macOS menu bar app showing local Codex desktop activity through the built-in Caps Lock LED. Installed at `/Applications/Agent Indicator.app`.

## Download

Download the built app from [GitHub Releases](https://github.com/MinchuanC/Agent-Indicator/releases/latest). Unzip it and drag **Agent Indicator.app** into Applications. The binary requires **Apple Silicon and macOS 27 or later**; it is ad-hoc signed and not Apple-notarized. See the release notes for first-launch instructions, then grant Input Monitoring as described below. Other Macs and keyboards remain unverified.

## Use

Click Agent Indicator’s menu bar symbol for a standard macOS dropdown. The **Chats** submenu lists chats in urgency order; each chat provides **Open Codex**, plus **Mark read** for ready responses. Opening the menu does not acknowledge responses. Pause, Settings, and Quit are available directly in the dropdown. Launching the app does not automatically open a panel; reopening it opens Settings.

| State | Keyboard light |
| --- | --- |
| Working | Even, steady blink: 400 ms on, 400 ms off |
| Needs you | Urgent triple burst: three 150 ms flashes, 150 ms apart, then 750 ms off |
| Response ready | Nearly solid with a brief dip: 2.7 s on, 300 ms off until marked read |
| Idle / unavailable / paused | Normal Caps Lock indication |

Priority: Needs you → Working → Response ready → Idle. Actual Caps Lock always takes precedence. A finished response does not certify that the overall task succeeded.

**Settings → Signals** previews each pattern for six seconds. **Settings → General** controls silent notifications and launch at login. Both are off initially. **Settings → Connection** shows access and monitoring status and provides Reconnect.

## Keyboard permission

In System Settings → Privacy & Security → Input Monitoring, add `/Applications/Agent Indicator.app` with **+**, then enable it. The separate **Agent Indicator LED Probe** entry does not grant permission to the finished app. Complete macOS authentication yourself. Quit/reopen if macOS requests it, then use Reconnect if needed.

This is an unsandboxed personal utility. Input Monitoring grants broad OS access, but the implementation registers no keystroke callbacks: it locates the built-in keyboard's LED output and writes that element. It never synthesizes Caps Lock presses or seizes the keyboard. Pause, sleep, inactive login session, and graceful quit restore the real modifier indication. Force-killing the app may prevent restoration; toggling Caps Lock restores the normal indication.

## Monitoring limits

The app reads version-dependent local Codex JSONL records, not an official desktop subscription. It handles explicit task starts, terminal completion, cancellation, synchronous questions, and matched asynchronous question replies. Child and CLI sessions are excluded using their first metadata record. Approval prompts are **not reliably exposed** by these records, so approval detection is explicitly labelled limited. The app never approves or denies actions.

Files modified within the last three days are discovered across the full session tree, including older chats resumed now. Existing files are tailed every three seconds; new/resumed files are discovered within fifteen seconds. Startup reconstructs recorded status but does not mark historical completions unread. A missing/unreadable monitored file shows unavailable instead of completion. Unfinished historical records can remain working until a new lifecycle event resolves them; stored records are not an authoritative live runtime registry. Exact-chat deep links are not used; Open Codex brings up the application.

Chat names, project names, and state are held in memory. Preferences are stored in macOS defaults. No prompts, response bodies, tool arguments, or credentials are persisted by this app; no network services, analytics, or third-party dependencies are used. No global Codex hook or approval settings are changed.

## Build

Requires the local Apple Swift compiler and macOS SDK. The current packaged build targets this Apple Silicon Mac on macOS 27.

```sh
./scripts/build-app.sh
open "/Applications/Agent Indicator.app"
```

Quit the installed app before rebuilding. The build script compiles with `swiftc`, installs to the existing main Applications location (or your personal Applications folder for a fresh install), and ad-hoc signs the bundle. Install the final binary before granting permissions: a rebuild can invalidate a prior grant. The downloadable build is ad-hoc signed; no Apple Developer account or notarization is configured. The Swift package manifest is also included; the direct build avoids this machine's broken Swift package runner.

One focused reducer smoke check:

```sh
mkdir -p .build
xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path .build/ModuleCache Sources/AgentIndicator/State.swift Tests/Smoke.swift -o .build/smoke
.build/smoke
```

The original hardware probe remains available through `scripts/probe-led.sh` and `scripts/install-probe.sh`.

## References

Reviewed before implementation; no source copied:

- [capsOS-Agent-Tracker](https://github.com/devkriter/capsOS-Agent-Tracker): AppKit agent indicator and independent HID LED control. Used as architecture inspiration; no explicit license was found.
- [setledsmac](https://github.com/damieng/setledsmac): minimal independent LED control, GPL-2.0.
- [openai/codex](https://github.com/openai/codex): lifecycle protocol and tests explaining why a Stop hook can precede continuation.
- [Apple notification authorization](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications) and [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice).

See `docs/feasibility.md` for hardware evidence and `docs/verification.md` for delivery checks and limits.
