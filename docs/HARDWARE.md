# Hardware and permissions

## Tuner

The tested tuner is a TEF6686 "headless" USB device (USB `1209:6687`) that
exposes a CDC-ACM serial port.

```bash
lsusb | grep -i -E 'tef|fmdx'
ls -l /dev/ttyACM*
```

Use a udev rule for a stable name and non-root access:

```udev
# /etc/udev/rules.d/99-tef6686.rules
SUBSYSTEM=="tty", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="6687", \
  MODE="0660", GROUP="audio", SYMLINK+="tef6686"
```

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
# then in .env:
TUNER_DEVICE=/dev/tef6686
```

The container runs as uid 1000 and joins the `audio` and `dialout` groups
(`AUDIO_GID`, `DIALOUT_GID` in `.env`). If you prefer not to change the udev
group, keep the device in `dialout` and make sure `DIALOUT_GID` matches the host.

## Audio

List capture devices on the host:

```bash
arecord -l
```

Typical output:

```
card 1: PCH [HDA Intel PCH], device 0: CS4208 Analog [CS4208 Analog]
card 2: Gen [Scarlett Solo 4th Gen], device 0: USB Audio [USB Audio]
card 3: Tuner [TEF668X Headless USB Tuner], device 0: USB Audio [USB Audio]
```

Set `audio.audioDevice` in `config/config.json` to the ALSA device you want:

- `hw:CARD=Scarlett,DEV=0` (recommended, stable across reboots)
- `hw:2,0` (card/device number; can change)
- `plughw:CARD=Tuner,DEV=0` if the app should resample/convert

Test outside the container first:

```bash
arecord -D hw:CARD=Scarlett,DEV=0 -f S16_LE -r 48000 -c 2 -d 5 /tmp/test.wav
aplay /tmp/test.wav
```

ALSA capture devices are exclusive: stop other programs (e.g. a local
`arecord`, PulseAudio/PipeWire capture) while the container uses the device.

## MPX / Signal plugin

The MetricsMonitor plugin needs a **second** audio input for the MPX baseband
(e.g. a Scarlett Solo input). Configure `MPXInputCard` in
`data/plugins_configs/metricsmonitor.json`; the plugin injects it into its client
files at startup.

The FM spectrum, RDS, scanner and audio stream only need the tuner's own audio
interface.

## Antennas

Up to four antennas can be named in `config/config.json` under `antennas`.
`antennaStartup` selects the default input; the Scanner plugin can switch
automatically while scanning. If no scanning runs, the startup antenna is kept.

## Time synchronisation

FMList uploads and MPX timing assume the host clock is correct. Enable NTP
(`systemd-timesyncd` or chrony) on the host; the container inherits the clock.
