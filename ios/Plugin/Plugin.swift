import Foundation;
import Capacitor;
import AVKit;

var AudioSessionRouteChangeReasons: [AVAudioSession.RouteChangeReason: String] = [
    .newDeviceAvailable: "new-device-available",
    .oldDeviceUnavailable: "old-device-unavailable",
    .categoryChange: "category-change",
    .override: "override",
    .wakeFromSleep: "wake-from-sleep",
    .noSuitableRouteForCategory: "no-suitable-route-for-category",
    .routeConfigurationChange: "route-config-change",
    .unknown: "unknown",
];

var AudioSessionInterruptionTypes: [AVAudioSession.InterruptionType: String] = [
    .began: "began",
    .ended: "ended",
];

var AudioSessionPorts: [AVAudioSession.Port: String] = [
    .airPlay: "airplay",
    .bluetoothLE: "bluetooth-le",
    .bluetoothHFP: "bluetooth-hfp",
    .bluetoothA2DP: "bluetooth-a2dp",
    .builtInSpeaker: "builtin-speaker",
    .builtInReceiver: "builtin-receiver",
    .HDMI: "hdmi",
    .headphones: "headphones",
    .lineOut: "line-out",
];

@objc(AudioSession)
public class AudioSession: CAPPlugin {
    @objc override public func load() {
        CAPLog.print("AudioSession.load() Initializing AudioSession plugin...");

        let nc = NotificationCenter.default;

        nc.addObserver(self,
                       selector: #selector(handleRouteChange),
                       name: AVAudioSession.routeChangeNotification,
                       object: nil);

        nc.addObserver(self,
                       selector: #selector(handleInterruption),
                       name: AVAudioSession.interruptionNotification,
                       object: AVAudioSession.sharedInstance);

        CAPLog.print("AudioSession.load() Plugin initialized!");
    }
    
    @objc func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reasonType = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return };
            let readableReason = AudioSessionRouteChangeReasons[reasonType] ?? "unknown";

        CAPLog.print("AudioSession.handleRouteChange() changed to \(readableReason)");

        
        self.notifyListeners("routeChanged", data: ["reason":readableReason]);
    }
    
    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
            let interruptValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let interruptType = AVAudioSession.InterruptionType(rawValue: interruptValue) else { return };
            let readableInterrupt = AudioSessionInterruptionTypes[interruptType] ?? "unknown";

        CAPLog.print("AudioSession.handleInterruption() interrupted status to \(readableInterrupt)");

        self.notifyListeners("interruption", data: ["type":readableInterrupt]);
    }
  
    @objc func currentOutputs(_ call: CAPPluginCall) {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs.map({AudioSessionPorts[$0.portType]});
        
        call.success([
            "outputs": outputs
        ]);
    }
    
    @objc func overrideOutput(_ call: CAPPluginCall) {
        let output = call.getString("type") ?? "unknown";

        if (output == "unknown") {
            call.reject("AudioSession.overrideOutput() no valid type provided.");
            return;
        }

        // make it async, cause in latest IOS it started to take ~1 sec and produce UI thread blocking issues
        DispatchQueue.global(qos: .utility).async {
            let session = AVAudioSession.sharedInstance();
            
            // make sure the AVAudioSession is properly configured
            do {
                try session.setActive(true);
                try session.setCategory(AVAudioSession.Category.playAndRecord, options:AVAudioSession.CategoryOptions.duckOthers);
            } catch {
                CAPLog.print("AudioSession.overrideOutput() error setting sessions settings.")
                call.reject("AudioSession.overrideOutput() error setting sessions settings.");
                return;
            }

            do {
                if (output == "speaker") {
                    try session.overrideOutputAudioPort(.speaker);
                } else {
                    try session.overrideOutputAudioPort(.none);
                }
                
                call.success();
            }
            catch {
                CAPLog.print("AudioSession.overrideOutput() could not override output port.")
                call.reject("AudioSession.overrideOutput() could not override output port.");
            }
        }
    }
}
