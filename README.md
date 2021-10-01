# capacitor-plugin-audiosession

**This plugin works on iOS only.**

This plugin is a port of <https://github.com/saghul/cordova-plugin-audioroute> and allows iOS applications to get notified about audio session intteruptions and route changes (for example when a headset is connected). To query and override the audio device in use is also supported.

## Installation

    npm install @studiokloek/capacitor-plugin-audiosession

For now this plugin works only in Capacitor 2.0+.

## Methods

### `currentOutputs()`

Get an Array of the currently connected audio ports. The possible elements are:

* line-out
* headphones
* bluetooth-a2dp
* builtin-receiver
* builtin-speaker
* hdmi
* airplay
* bluetooth-le
* unknown

Example:

```` javascript
import { Plugins } from '@capacitor/core';
const { AudioSession } = Plugins,

// list all current outputs
const { outputs }  = await AudioSession.currentOutputs(),
console.log(outputs)
````

### `overrideOutput({type:string})`

Overrides the audio output device. The output `type` must be one of `default` or `speaker`.

Example:

```` javascript
import { Plugins } from '@capacitor/core';
const { AudioSession } = Plugins,

// force output on speker
const success = await AudioSession.overrideOutput({ type: 'speaker' });
console.log(success)
````

## Events

### `interruption`

When the audio playback was interrupted (or resumed) this event will be fired. The event contains the `type` which can be `began` or `ended`.

Example:

```` javascript
import { Plugins } from '@capacitor/core';
const { AudioSession } = Plugins,

AudioSession.addListener('interruption', (event) => {
    console.log('Audio interruption updated: ' + event.type);
});
````

### `routeChanged`

When the audio route has changed a 'audioroute-changed' event will be fired. The event contains the `reason` which can be one of:

* unknown
* new-device-available
* old-device-unavailable
* category-change
* override
* wake-from-sleep
* no-suitable-route-for-category
* route-config-change

Example:

```` javascript
import { Plugins } from '@capacitor/core';
const { AudioSession } = Plugins,

AudioSession.addListener('routeChanged', (event) => {
    console.log('Audio route changed: ' + event.reason);
});
````

## License

MIT

## Author

Martijn Swart <https://studiokloek.nl>

Based on work from: Saúl Ibarra Corretgé <saghul@gmail.com>
