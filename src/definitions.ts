declare module '@capacitor/core' {
  interface PluginRegistry {
    AudioSession: AudioSessionPlugin;
  }
}

export const RouteChangeReasons: Record<string, string> = {
  NEW_DEVICE_AVAILABLE: "new-device-available",
  OLD_DEVICE_UNAVAILABLE: "old-device-unavailable",
  CATEGORY_CHANGE: "category-change",
  OVERRIDE: "override",
  WAKE_FROM_SLEEP: "wake-from-sleep",
  NO_SUITABLE_ROUTE_FOR_CATEGORY: "no-suitable-route-for-category",
  ROUTE_CONFIGURATION_CHANGE: "route-config-change",
  UNKNOWN: "unknown",
};

export const InterruptionTypes: Record<string, string> = {
  BEGAN: "began",
  ENDED: "ended",
};

export const AudioSessionPorts: Record<string, string> = {
  AIR_PLAY: "airplay",
  BLUETOOTH_LE: "bluetooth-le",
  BLUETOOTH_HFP: "bluetooth-hfp",
  BLUETOOTH_A2DP: "bluetooth-a2dp",
  BUILT_IN_SPEAKER: "builtin-speaker",
  BUILT_IN_RECEIVER: "builtin-receiver",
  HDMI: "hdmi",
  HEADPHONES: "headphones",
  LINE_OUT: "line-out",
};

export type OutputOverrideType = 'default' | 'speaker';

export interface AudioSessionPlugin {
  currentOutputs(): Promise<string[]>;
  overrideOutput(type:OutputOverrideType): Promise<boolean>;
}
