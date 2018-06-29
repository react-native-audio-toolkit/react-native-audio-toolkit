//@flow

import MediaStates from "./MediaStates";

export type FsPath = string;
export type Callback = (err?: Error) => any;
export type CallbackWithPath = (err: ?Error, fsPath?: FsPath) => any;
export type CallbackWithBoolean = (err: ?Error, bool: boolean) => any;
