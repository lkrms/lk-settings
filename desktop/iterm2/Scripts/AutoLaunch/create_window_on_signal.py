#!/usr/bin/env python3

# To create a new iTerm2 window:
#
# pkill -SIGUSR1 -fnu "$EUID" '/create_window_on_signal.py$'

import iterm2
import signal


async def main(connection):
    global exit_code
    app = await iterm2.async_get_app(connection)
    while True:
        print("Waiting for signal")
        sig = signal.sigwait(
            [signal.SIGHUP, signal.SIGINT, signal.SIGTERM, signal.SIGUSR1])
        if sig == signal.SIGUSR1:
            print("Creating new window")
            window = await iterm2.Window.async_create(connection)
            if window is not None:
                await window.async_activate()
                await app.async_activate(False)
            else:
                print("Unable to create window")
            continue

        print("Terminating on signal {}".format(sig))
        exit_code = sig
        break


exit_code = 0

iterm2.run_until_complete(main)
exit(exit_code)
