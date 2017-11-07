'use strict';

const MediaStates = {
  DESTROYED: -2,
  ERROR: -1,
  IDLE: 0,
  PREPARING: 1,
  PREPARED: 2,
  BUFFERING: 3,
  SEEKING: 4,
  PLAYING: 4,
  RECORDING: 5,
  PAUSED: 6
};

export default MediaStates;
