'use strict';

let MediaStates = {
  DESTROYED: -2,
  ERROR: -1,
  IDLE: 0,
  PREPARING: 1,
  PREPARED: 2,
  SEEKING: 3,
  PLAYING: 4,
  RECORDING: 4,
  PAUSED: 5
};

export default MediaStates;
