import AppKit
import Carbon.HIToolbox

/// Registers a system-wide hot key using the Carbon Hot Key API.
///
/// Unlike a `CGEventTap`, this needs **no Accessibility permission** — which is
/// why Halo uses a modifier+key combo (⌥Tab) as its trigger. The C event handler
/// can't capture Swift context, so it routes through the shared instance.
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    /// Called on the main actor when the registered hot key is pressed.
    var onPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    /// - Parameters:
    ///   - keyCode: a virtual key code (`Carbon.HIToolbox` `kVK_*`).
    ///   - modifiers: Carbon modifier mask (`optionKey`, `cmdKey`, `controlKey`, `shiftKey`).
    func register(keyCode: UInt32, modifiers: UInt32) {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, _, _ in
            MainActor.assumeIsolated { HotkeyManager.shared.onPressed?() }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x484C_4F31), id: 1) // 'HLO1'
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}
