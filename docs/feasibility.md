# Feasibility — 2026-11-11

## Environment

- MacBook Pro Mac15,6, Apple M3 Pro, macOS 27.2 (26B5091g).
- Installed standalone Codex package: 0.166.0, aarch64-apple-darwin. This is not proof of the desktop client's version.
- Apple Swift 6.4. Direct swiftc compilation succeeded using a project-local module cache.
- `swift run` failed before compilation because the installed developer tools cannot load BuildServerProtocol.framework. No system toolchain settings were changed.

## Hardware gate: PASSED after user permission grant

The IORegistry reports Apple Internal Keyboard / Trackpad devices with Built-In = Yes and RequiresTCCAuthorization = Yes.

The compiled LED probe returned:

```
Input Monitoring access: 1
Manager open: -536870174
```

The SDK defines this result (0xe00002e2) as kIOReturnNotPermitted. The same result occurred outside the execution sandbox. An explicit IOHIDRequestAccess call also returned false. No independent LED write occurred. This does not prove incompatibility; OS access has not been established.

Required next evidence: grant actual macOS access to the probe/host, obtain successful nonexclusive HID access and independent LED writes, then confirm physical blinking, unaffected lowercase typing, Caps Lock override, and restoration. Stop if this requires modifier toggling or privileged workarounds.

## Codex gate: INCOMPLETE

Read-only inspection of today's local JSONL records found 248 task_started, 233 task_complete, and 17 turn_aborted events at inspection time. Terminal events carry turn_id; task_complete also carries root_turn_id and completed_at. Records also contain structured request_user_input and request_user_input_async function calls. Only event names, counts, and field names were printed; no conversation text was copied into this project.

This establishes candidate sources for start, terminal, and structured-input detection. It does not establish a complete live desktop state reader. A synchronous input call and an asynchronous question have different semantics: an async tool returning does not mean the question was answered. Approval requests may be resolved automatically, so a PermissionRequest hook does not alone prove a visible human prompt.

Required next evidence: correlate a real desktop input request and its answer, approval pending and resolution, resumed work, terminal completion, and parent/child identity. Unknown formats or missing resolution evidence must produce unavailable status rather than guessed completion. Do not start another app-server to infer the desktop app's live state.

Existing global hooks are present. No hook definitions, Codex settings, permissions, or databases were modified.

## Delivery boundary

Only the feasibility probe is implemented. The hardware gate has passed; the Codex integration gate remains incomplete and blocks the full utility. Menu bar UI, notifications, login item, runtime event reader, reducer, and local app installation have not been implemented or verified. No synthetic event was presented as a real Codex approval or completion.

## Named permission entry

Installed an ad-hoc signed feasibility probe at `~/Applications/Agent Indicator LED Probe.app`, bundle ID `com.minchuan.AgentIndicator.LEDProbe`, using `scripts/install-probe.sh`. Launching that app produced the same denied-access result. Native System Settings inspection then confirmed **Agent Indicator LED Probe.app** appears in Input Monitoring with its switch off. The pane is open for the user to grant access; no permission switch was changed by the agent. This is a concrete OS-consent blocker, not evidence of incompatible LED hardware.

## Hardware gate completion

The user enabled Input Monitoring for the installed **Agent Indicator LED Probe.app**. Native System Settings inspection confirmed its switch was on. Relaunching the unchanged installed binary returned:

```
Input Monitoring access: 0
Manager open: 0
Found: Apple Internal Keyboard / Trackpad, Caps Lock output element
LED on result: 0
LED on result: 0
Restore result: 0
```

After an announced replay, the user answered **All passed** to visible two-flash behavior, normal lowercase typing, and normal Caps Lock operation afterward. Hardware gate passed on this Mac and installed binary only. Forced-crash cleanup and continuous pattern override were not tested.

## Remaining integration blocker

A bounded read-only inspection of local runtime log metadata found approval-related records, but inspected records described approval policy/settings rather than a human-visible pending approval and its matching resolution. Today's transcript event inventory did not establish an approval-request/resolution pair. No reliable replacement has been demonstrated, and no global hooks were installed to guess this state.

The next integration task is to establish an actual desktop approval pending/resolved signal, correlated by request and turn ID, without changing approval policy or launching a separate runtime. Current Codex authorization uses a never-ask approval policy, so this chat cannot generate a genuine approval prompt merely for testing. Do not force a permission escalation or fabricate an approval event to pass the gate. Until that source is established, the agreed full-interface gate remains closed.

## Full application delivery update

The user subsequently requested the complete utility despite the unresolved approval-observation gate. A native menu bar app is now implemented, compiled, ad-hoc signed, installed, and running at `~/Applications/Agent Indicator.app`. Local question and completion monitoring is enabled, with approval coverage explicitly labelled limited. No approval settings or global hooks were changed. See `verification.md` for current runtime evidence and remaining limits; earlier prototype-only delivery boundaries above describe the earlier gate, not the current artifact.
