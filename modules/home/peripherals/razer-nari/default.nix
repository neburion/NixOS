{ pkgs, ... }:

# `nari-battery` — the Razer Nari Essential's charge, as `<percent> <millivolts>`:
#
#     56 3856
#
# Exits 1 when the dongle is gone or the headset is off, so silence means
# absence rather than zero.
#
# Nothing off the shelf reads this headset. OpenRazer has never supported any
# Nari — the support request is closed as not planned, and the kraken driver's
# id table stops at 0x0560 — so razergenie only ever showed an empty list, and
# it is gone from this tree. HeadsetControl carries no Razer device at all.
#
# What works is the vendor protocol the dongle already advertises: a 63-byte
# feature report on id 0xFF. Write a query into it, read the answer back off
# the same report. Captured off this dongle, and matching the exchange
# documented for the 0x051C Nari:
#
#   request   FF 0A 00 FD 04 12 F1 02 05  00…
#   response  FF 0F 05 FE 12 04 1F 08 05 03 05 01 │0F 10│ 50 │ 00…
#                                                   mV     not a percentage
#
# Bytes 12-13 are the cell voltage, big-endian, and they are the only field in
# here that has been watched move: 4096 mV on the charger, 3864 then 3856
# discharging, stepping by 8 mV exactly as the 0x051C notes describe. Byte 14
# reads 0x50 at 3856 mV and 0x50 at 4096 mV, so it is some fixed device field
# and not a charge level; an earlier version of this module published it as
# one. Nothing in the frame has been identified as a charging flag either, so
# the menu shows no charging state for the headset.
#
# The percentage below is therefore computed here, from the voltage, against a
# generic 1S Li-ion resting curve. It is an estimate: the cell sags under load,
# so the reading runs low while audio is playing, and the flat middle of the
# curve means an 8 mV step can move it several points. The menu shows the
# voltage beside it for exactly that reason.
#
# No libusb and no kernel-driver detaching: plain hidraw ioctls. The node is
# root-owned until system.nix hands it over.

let
  reader = pkgs.writeText "nari-battery.py" ''
    import array, fcntl, glob, os, sys, time

    VENDOR = "1532"

    # The dongle first: it is the one that stays plugged in, and it answers
    # whether the headset is on the charger or not. 051F is the headset's own
    # interface, which appears only while it is on the cable — a fallback for
    # charging it with the dongle somewhere else.
    PRODUCTS = ["051E", "051F"]

    REPORT_ID = 0xFF
    SIZE      = 64                        # 1 id + 63 payload
    QUERY     = bytes([0xFF, 0x0A, 0x00, 0xFD, 0x04, 0x12, 0xF1, 0x02, 0x05])

    # Voltage is the measurement; percent is this table read backwards.
    # Generic single-cell Li-ion at rest, 4.20 V charged to 3.30 V empty.
    CURVE = [
        (4200, 100), (4100, 90), (4000, 80), (3930, 70), (3870, 60),
        (3830,  50), (3790, 40), (3770, 30), (3740, 20), (3680, 10),
        (3500,   5), (3300,  0),
    ]


    def _hid_ioctl(nr):
        # _IOC(read|write, 'H', nr, SIZE)
        return (3 << 30) | (SIZE << 16) | (ord("H") << 8) | nr


    HIDIOCSFEATURE = _hid_ioctl(0x06)
    HIDIOCGFEATURE = _hid_ioctl(0x07)


    def nodes():
        wanted = ["0003:0000%s:0000%s" % (VENDOR, p) for p in PRODUCTS]
        found = {}
        for node in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
            try:
                with open(os.path.join(node, "device", "uevent")) as fh:
                    uevent = fh.read().upper()
            except OSError:
                continue
            for want in wanted:
                if want in uevent and want not in found:
                    found[want] = "/dev/" + os.path.basename(node)
        return [found[w] for w in wanted if w in found]


    def exchange(fd):
        out = array.array("B", QUERY + bytes(SIZE - len(QUERY)))
        fcntl.ioctl(fd, HIDIOCSFEATURE, out, True)
        back = array.array("B", bytes([REPORT_ID]) + bytes(SIZE - 1))
        fcntl.ioctl(fd, HIDIOCGFEATURE, back, True)
        frame = bytes(back)
        return (frame[12] << 8) | frame[13]


    def millivolts(path):
        # A dongle whose headset is off answers with an empty frame, and so
        # does one whose headset has only just woken — the first exchange
        # after an idle spell came back zeroed once and was fine 4s later.
        # Retry before calling it absence.
        fd = os.open(path, os.O_RDWR)
        try:
            for attempt in range(3):
                if attempt:
                    time.sleep(0.2)
                found = exchange(fd)
                if found:
                    return found
        finally:
            os.close(fd)
        return 0


    def percent(mv):
        if mv >= CURVE[0][0]:
            return CURVE[0][1]
        for (hi_mv, hi_pc), (lo_mv, lo_pc) in zip(CURVE, CURVE[1:]):
            if mv >= lo_mv:
                span = hi_mv - lo_mv
                return int(round(lo_pc + (mv - lo_mv) * (hi_pc - lo_pc) / span))
        return 0


    for path in nodes():
        try:
            mv = millivolts(path)
        except OSError as exc:
            print("nari-battery: %s: %s" % (path, exc), file=sys.stderr)
            continue
        if mv:
            print("%d %d" % (percent(mv), mv))
            sys.exit(0)

    sys.exit(1)
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
