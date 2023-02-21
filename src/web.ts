import { WebPlugin } from '@capacitor/core';

import type {
  AudioSessionPlugin,
  AudioSessionPorts,
  OutputOverrideType,
} from './definitions';

export class AudioSessionWeb extends WebPlugin implements AudioSessionPlugin {
  async currentOutputs(): Promise<AudioSessionPorts[]> {
    console.log(
      'AudioSessionPlugin.currentOutputs()',
      'only available on a iOS device.',
    );

    return [];
  }

  async overrideOutput(type: OutputOverrideType): Promise<boolean> {
    console.log(
      `AudioSessionPlugin.currentOutputs(${type})`,
      'only available on a iOS device.',
    );

    return false;
  }
}
