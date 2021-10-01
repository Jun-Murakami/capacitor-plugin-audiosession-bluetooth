import { WebPlugin } from '@capacitor/core';
import { AudioSessionPlugin, OutputOverrideType } from './definitions';

export class AudioSessionWeb extends WebPlugin implements AudioSessionPlugin {
  constructor() {
    super({
      name: 'AudioSession',
      platforms: ['web'],
    });
  }

  async currentOutputs(): Promise<string[]> {
    console.log('AudioSessionPlugin.currentOutputs()', 'only available on a iOS device.');

    return [];
  }

  async overrideOutput(type:OutputOverrideType): Promise<boolean> {
    console.log(`AudioSessionPlugin.currentOutputs(${type})`, 'only available on a iOS device.');

    return false;
  }
}

const AudioSession = new AudioSessionWeb();

export { AudioSession };

import { registerWebPlugin } from '@capacitor/core';
registerWebPlugin(AudioSession);
