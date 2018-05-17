'use strict';

const MediaStates = {
  DESTROYED: -2,
  ERROR: -1,
  IDLE: 0,
  PREPARING: 1,
  PREPARED: 2,
  BUFFERING: 3,
  PLAYING: 4,
  SEEKING: 5,
  RECORDING: 6,
  PAUSED: 7
};

export default MediaStates;
