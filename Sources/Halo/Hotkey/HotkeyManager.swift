import AppKit
import Carbon.HIToolbox

/// Registers a system-wide hot key using the Carbon Hot Key API.
///
/// Needs **no Accessibility permission** — which is why Halo uses a modifier+key
/// combo (⌥Tab). Carbon reports both press and release, enabling a hold-and-
/// release selection gesture without an event tap. The C event handler can't
/// capture Swift context, so it routes through the shared instance.
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    func register(keyCode: UInt32, modifiers: UInt32) {
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]

        let handler: EventHandlerUPP = { _, event, _ in
            let kind = event.map { GetEventKind($0) } ?? 0
            MainActor.assumeIsolated {
                switch Int(kind) {
                case kEventHotKeyPressed: HotkeyManager.shared.onPressed?()
                case kEventHotKeyReleased: HotkeyManager.shared.onReleased?()
                default: break
                }
            }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), handler, 2, &eventTypes, nil, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x484C_4F31), id: 1) // 'HLO1'
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
