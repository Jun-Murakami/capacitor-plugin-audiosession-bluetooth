import Foundation
import Capacitor
import AVKit

var AudioSessionOverrideTypes: [AVAudioSession.PortOverride: String] = [
    .none: "none",
    .speaker: "speaker"
]

var AudioSessionRouteChangeReasons: [AVAudioSession.RouteChangeReason: String] = [
    .newDeviceAvailable: "new-device-available",
    .oldDeviceUnavailable: "old-device-unavailable",
    .categoryChange: "category-change",
    .override: "override",
    .wakeFromSleep: "wake-from-sleep",
    .noSuitableRouteForCategory: "no-suitable-route-for-category",
    .routeConfigurationChange: "route-config-change",
    .unknown: "unknown"
]

var AudioSessionInterruptionTypes: [AVAudioSession.InterruptionType: String] = [
    .began: "began",
    .ended: "ended"
]

var AudioSessionPorts: [AVAudioSession.Port: String] = [
    .airPlay: "airplay",
    .bluetoothLE: "bluetooth-le",
    .bluetoothHFP: "bluetooth-hfp",
    .bluetoothA2DP: "bluetooth-a2dp",
    .builtInSpeaker: "builtin-speaker",
    .builtInReceiver: "builtin-receiver",
    .HDMI: "hdmi",
    .headphones: "headphones",
    .lineOut: "line-out"
]

public typealias AudioSessionRouteChangeObserver = (String) -> Void
public typealias AudioSessionInterruptionObserver = (String) -> Void
public typealias AudioSessionOverrideCallback = (Bool, String?, Bool?) -> Void

public class AudioSession: NSObject {

    var routeChangeObserver: AudioSessionRouteChangeObserver?
    var interruptionObserver: AudioSessionInterruptionObserver?

    var currentOverride: String?

    private var autoSwitchBluetooth: Bool = false
    private var priorityOrder: [AVAudioSession.Port] = [
        .lineOut,
        .headphones,
        .bluetoothA2DP,
        .bluetoothHFP,
        .builtInSpeaker
    ]

    public func load() {
        let nc = NotificationCenter.default

        nc.addObserver(self,
                       selector: #selector(self.handleRouteChange),
                       name: AVAudioSession.routeChangeNotification,
                       object: nil)

        nc.addObserver(self,
                       selector: #selector(self.handleInterruption),
                       name: AVAudioSession.interruptionNotification,
                       object: AVAudioSession.sharedInstance)
    }

    // EVENTS

    @objc func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reasonType = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        let readableReason = AudioSessionRouteChangeReasons[reasonType] ?? "unknown"

        CAPLog.print("AudioSession.handleRouteChange() changed to \(readableReason)")

        // 自動切り替えが有効な場合、最適な出力に切り替え
        if self.autoSwitchBluetooth {
            self.switchToOptimalOutput()
        }

        self.routeChangeObserver?(readableReason)
    }

    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let interruptValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptType = AVAudioSession.InterruptionType(rawValue: interruptValue) else { return }
        let readableInterrupt = AudioSessionInterruptionTypes[interruptType] ?? "unknown"

        CAPLog.print("AudioSession.handleInterruption() interrupted status to \(readableInterrupt)")

        self.interruptionObserver?(readableInterrupt)
    }

    // METHODS

    public func currentOutputs() -> [String?] {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs.map({AudioSessionPorts[$0.portType]})

        return outputs
    }

    public func overrideOutput(_output: String, _callback: @escaping AudioSessionOverrideCallback) {
        if _output == "unknown" {
            return _callback(false, "No valid output provided...", nil)
        }

        if self.currentOverride == _output {
            return _callback(true, nil, nil)
        }

        // make it async, cause in latest IOS it started to take ~1 sec and produce UI thread blocking issues
        DispatchQueue.global(qos: .utility).async {
            let session = AVAudioSession.sharedInstance()

            // make sure the AVAudioSession is properly configured
            do {
                try session.setActive(true)
                try session.setCategory(.playAndRecord, options: [.defaultToSpeaker,.allowBluetooth, .allowBluetoothA2DP,.allowAirPlay,.mixWithOthers])
            } catch {
                CAPLog.print("AudioSession.overrideOutput() error setting sessions settings.")
                _callback(false, "Error setting sessions settings.", true)
                return
            }

            do {
                if _output == "speaker" {
                    try session.overrideOutputAudioPort(.speaker)
                } else {
                    try session.overrideOutputAudioPort(.none)
                }

                self.currentOverride = _output

                CAPLog.print("currentOverride: " + (self.currentOverride ?? "") + " - " + _output)

                _callback(true, nil, nil)
            } catch {
                CAPLog.print("AudioSession.overrideOutput() could not override output port.")
                _callback(false, "Could not override output port.", true)
            }
        }
    }

    public func configure(options: [String: Any]) {
        if let autoSwitch = options["autoSwitchBluetooth"] as? Bool {
            self.autoSwitchBluetooth = autoSwitch
        }
        
        if let priorities = options["priorityOrder"] as? [String] {
            self.priorityOrder = priorities.compactMap { portString in
                return AudioSessionPorts.first { $0.value == portString }?.key
            }
        }
        
        if self.autoSwitchBluetooth {
            // オーディオセッションを明示的にアクティベート
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playAndRecord, options: [.defaultToSpeaker,.allowBluetooth, .allowBluetoothA2DP,.allowAirPlay,.mixWithOthers])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                
                // 遅延後に優先デバイスチェック
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.forceUpdateAudioRoute()
                }
            } catch {
                CAPLog.print("AudioSession configure error: \(error.localizedDescription)")
            }
        }
    }

    private func forceUpdateAudioRoute() {
        let session = AVAudioSession.sharedInstance()
        do {
            // 現在のルートをリセット
            try session.setActive(false)
            try session.setActive(true)
            
            // 優先デバイスに切り替え
            self.switchToOptimalOutput()
        } catch {
            CAPLog.print("Force update audio route failed: \(error.localizedDescription)")
        }
    }

    private func getAudioCategoryOptions(for portType: AVAudioSession.Port?) -> AVAudioSession.CategoryOptions {
        var options: AVAudioSession.CategoryOptions = [
            .defaultToSpeaker,
            .allowAirPlay,
            .mixWithOthers
        ]
        
        // Bluetoothデバイスの場合、適切なオプションを追加
        if let port = portType {
            switch port {
            case .bluetoothHFP:
                options.insert(.allowBluetooth)
            case .bluetoothA2DP:
                options.insert(.allowBluetoothA2DP)
            default:
                // その他のデバイスタイプの場合は両方のオプションを設定
                options.insert(.allowBluetooth)
                options.insert(.allowBluetoothA2DP)
            }
        }
        
        return options
    }

    private func switchToOptimalOutput() {
        let session = AVAudioSession.sharedInstance()
        let currentOutputs = session.currentRoute.outputs
        
        // 現在の出力が優先順位に合致しているかチェック
        let currentPort = currentOutputs.first?.portType
        if let current = currentPort, priorityOrder.contains(current) {
            // 現在の出力が優先順位内の場合、適切なオプションを設定
            do {
                let options = getAudioCategoryOptions(for: current)
                try session.setCategory(.playAndRecord, options: options)
                try session.setActive(true)
            } catch {
                CAPLog.print("Failed to configure audio session: \(error.localizedDescription)")
            }
            return
        }
        
        // 優先順位に従って切り替え
        for priority in self.priorityOrder {
            if let _ = currentOutputs.first(where: { $0.portType == priority }) {
                do {
                    let options = getAudioCategoryOptions(for: priority)
                    try session.setCategory(.playAndRecord, options: options)
                    
                    if priority == .builtInSpeaker {
                        try session.overrideOutputAudioPort(.speaker)
                    } else {
                        try session.overrideOutputAudioPort(.none)
                    }
                    try session.setActive(true)
                    break
                } catch {
                    CAPLog.print("Failed to switch to \(priority): \(error.localizedDescription)")
                }
            }
        }
    }
}
