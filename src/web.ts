import { WebPlugin } from '@capacitor/core';

import type {
  AudioSessionPlugin,
  AudioSessionPorts,
  AudioSessionOptions,
  OutputOverrideType,
  OverrideResult,
  RouteChangeListener,
  InterruptionListener,
} from './definitions';

export class AudioSessionWeb extends WebPlugin implements AudioSessionPlugin {
  async currentOutputs(): Promise<AudioSessionPorts[]> {
    console.log(
      'AudioSessionPlugin.currentOutputs()',
      'only available on a iOS device.',
    );

    return [];
  }

  async overrideOutput(type: OutputOverrideType): Promise<OverrideResult> {
    console.log(
      `AudioSessionPlugin.overrideOutput(${type})`,
      'only available on a iOS device.',
    );

    return {
      success: false,
      message: '',
    };
  }

  async configure(options: AudioSessionOptions): Promise<void> {
    console.log(
      `AudioSessionPlugin.configure()`,
      'only available on a iOS device.',
      options
    );
  }

  override addListener(
    eventName: 'routeChanged' | 'interruption',
    listenerFunc: RouteChangeListener | InterruptionListener,
  ): Promise<any> & any {
    console.log(
      `AudioSessionPlugin.addListener(${eventName})`,
      'only available on a iOS device.',
    );
    return super.addListener(eventName, listenerFunc);
  }
}
