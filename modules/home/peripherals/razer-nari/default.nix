{ pkgs, ... }:

# `nari-battery` — the Razer Nari Essential's charge, as `<percent> <millivolts>`:
#
#     80 3952
#
# Exits 1 when the dongle is unplugged or answers an empty frame, so silence
# means absence rather than zero.
#
# Nothing off the shelf reads this headset. OpenRazer has never supported any
# Nari — the support request is closed as not planned, and the kraken driver's
# id table stops at 0x0560 — so razergenie only ever showed an empty list, and
# it is gone from this tree. HeadsetControl carries no Razer device at all.
#
# What works is the vendor protocol the dongle already advertises: a 63-byte
# feature report on id 0xFF. Write a query into it, read the answer back off
# the same report. The layout below was captured off this dongle, cross-checked
# against the 0x051C Nari's documented exchange:
#
#   request   FF 0A 00 FD 04 12 F1 02 05  00…
#   response  FF ss ss FE 12 04 11 08 05 05 03 05 │0F 70│ 50 │ 00…
#                                                   mV     percent
#
# Bytes 1-2 are a sequence that changes per call; everything from 4 onward held
# still across reads while the voltage tracked the charge, which is what rules
# out byte 14 being a checksum over the frame. Percent and voltage corroborate
# each other on a 1S cell — 3.95 V is where a Li-ion sits at about 80% — but
# only the voltage has been watched moving, so the menu shows both and you can
# see them disagree if byte 14 ever turns out to be something else.
#
# No libusb and no kernel-driver detaching: plain hidraw ioctls. The node is
# root-owned until system.nix hands it over.

let
  reader = pkgs.writeText "nari-battery.py" ''
    import array, fcntl, glob, os, sys

    VENDOR, PRODUCT = "1532", "051F"      # the dongle, not the headset's own
                                          # interface (051E) it shows up as
                                          # while charging on the cable

    REPORT_ID = 0xFF
    SIZE      = 64                        # 1 id + 63 payload
    QUERY     = bytes([0xFF, 0x0A, 0x00, 0xFD, 0x04, 0x12, 0xF1, 0x02, 0x05])


    def _hid_ioctl(nr):
        # _IOC(read|write, 'H', nr, SIZE)
        return (3 << 30) | (SIZE << 16) | (ord("H") << 8) | nr


    HIDIOCSFEATURE = _hid_ioctl(0x06)
    HIDIOCGFEATURE = _hid_ioctl(0x07)


    def dongle():
        want = "0003:0000%s:0000%s" % (VENDOR, PRODUCT)
        for node in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
            try:
                with open(os.path.join(node, "device", "uevent")) as fh:
                    uevent = fh.read()
            except OSError:
                continue
            if want in uevent.upper():
                return "/dev/" + os.path.basename(node)
        return None


    def exchange(path):
        fd = os.open(path, os.O_RDWR)
        try:
            out = array.array("B", QUERY + bytes(SIZE - len(QUERY)))
            fcntl.ioctl(fd, HIDIOCSFEATURE, out, True)
            back = array.array("B", bytes([REPORT_ID]) + bytes(SIZE - 1))
            fcntl.ioctl(fd, HIDIOCGFEATURE, back, True)
            return bytes(back)
        finally:
            os.close(fd)


    path = dongle()
    if path is None:
        sys.exit(1)

    try:
        frame = exchange(path)
    except OSError as exc:
        print("nari-battery: %s: %s" % (path, exc), file=sys.stderr)
        sys.exit(1)

    millivolts = (frame[12] << 8) | frame[13]
    percent    = frame[14]

    # A dongle with no headset paired answers, but with nothing in it.
    if millivolts == 0 and percent == 0:
        sys.exit(1)

    print("%d %d" % (percent, millivolts))
  '';
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "nari-battery";
      runtimeInputs = with pkgs; [ python3 ];
      text = ''
        exec python3 ${reader}
      '';
    })
  ];
}
