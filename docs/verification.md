# Delivery verification — 2026-11-11

## Implemented

- Swift/AppKit NSStatusItem with a standard NSMenu dropdown, nested chat menus, and a native SwiftUI Settings window.
- Urgency ordering in the Chats submenu, per-chat Mark read, Open Codex, Pause/Resume, Settings, and Quit.
- General, Signals, and Connection settings; six-second cancellable LED previews; silent notification authorization/status; SMAppService login registration and error reporting.
- Background read-only incremental desktop event monitoring; parent/child filtering; synchronous and asynchronous question identity matching; explicit turn completion/cancellation; historical completion suppression; archived-file handling.
- Public IOKit built-in LED writes, real Caps Lock priority, value-change-only writes, failed-write shutdown, graceful restoration, wake rediscovery, and inactive-session suspension.

## Focused smoke evidence

- Direct Swift compiler build succeeded and the app was ad-hoc signed and installed at `~/Applications/Agent Indicator.app`.
- One assert-based reducer smoke passed: working → question → matching answer → ready, multi-chat priority, acknowledgement, cancellation, stale completion, duplicate start, and ignoring async delivery acknowledgement.
- Native installed UI showed this chat Working and 19 discovered desktop chats; Settings General and Signals tabs rendered with expected controls.
- Issuing an actual structured asynchronous question changed the live installed app to Needs you and identified this chat as waiting for an answer. The immediate async tool return did not clear it.
- The earlier installed LED probe passed independent writes and restoration. The user confirmed visible flashes, normal lowercase typing, and normal Caps Lock afterward.

## Native surface behavior

| Surface | Controls and keyboard | Access and presentation |
| --- | --- | --- |
| Menu bar dropdown | NSStatusItem/NSMenu; standard arrows, Return and Escape; Chats submenu with per-chat actions; opening does not acknowledge chats | Native system menu typography and selection; symbols plus text rather than color alone; no automatic popover or focus activation |
| Settings | Standard titled/closable NSWindow, SwiftUI tab bar, grouped forms, toggles/buttons; Command-comma opens Settings, Command-Q quits; native focus/close behavior | Semantic native light/dark rendering; no custom transparency or motion; actual OS authorization and denial states; previews disabled without keyboard access |
| Permission/notifications | Real macOS APIs and System Settings; no imitation consent sheets; user handles authentication | Input Monitoring is broader than LED access at OS level. No keyboard-input callbacks registered. Notification content contains chat title and state only |

## Pending / limitations

- Final app keyboard permission and the double-flash preview passed on 2026-11-12; see the installed-setup evidence below.
- Approval prompt/resolution coverage is partial and visibly labelled. No full approval lifecycle was verified.
- Completion and acknowledgement are reducer-smoke verified; no synthetic event was inserted into real chat logs. This chat's final completion cannot be observed before this report is written.
- Notifications, login-item behavior, sleep/wake, inactive login sessions, force-crash cleanup, physical Caps Lock priority during continuous patterns, and full VoiceOver interaction were not runtime verified.
- Only this Apple Silicon/macOS 27 environment is targeted. No public signing/notarization or cross-Mac compatibility claim.
- Swift 5 language mode is explicit. The compiler reports Sendable warnings for a private reader confined to a serial dispatch queue; Swift 6 migration is outside this delivery.

No broad regression suite, lint stack, benchmark, or exhaustive compatibility matrix was run.

Dropdown revision: replaced the popover with a standard attached NSMenu and removed the orphaned panel/filter code. The revised build succeeded and the updated Settings window was observed. A direct live status-menu click was not verified through computer use. No reducer tests were rerun for this presentation-only change.

## Installed keyboard setup — 2026-11-12

The app was relocated to `/Applications/Agent Indicator.app` by the user. After the user removed and re-added that exact app in Input Monitoring, the unchanged installed app reported **Built-in keyboard connected**. The Needs you preview showed Playing, returned to Preview after its six-second duration, and the user confirmed visible double flashes. No binary rebuild was performed after this fresh permission grant. Documentation and the installer were updated to preserve the relocated installation on subsequent builds.

The dropdown itself is not exposed in the native automation target. A user-assisted action smoke passed: the user selected Pause indicators from the actual dropdown, then native inspection independently showed Pause indicators = on and all previews disabled. The agent switched Pause indicators off in Settings and observed all previews become enabled again. Keyboard remained connected. The app is left resumed. This verifies that dropdown action, not every menu command.
