{ pkgs, lib, ... }:

# Bluetooth pairing agent. Replaces blueman-applet's agent functionality.
# Shows a GTK dialog when a device requests passkey confirmation instead of
# requiring the user to type "yes" in bluetoothctl.

let
  giPath = lib.makeSearchPath "lib/girepository-1.0" (with pkgs; [
    gtk3 pango.out glib.out gdk-pixbuf harfbuzz.out at-spi2-core gobject-introspection
  ]);

  py = pkgs.python3.withPackages (ps: with ps; [ pygobject3 dbus-python ]);

  script = pkgs.writeText "bt-agent.py" ''
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk, GLib
    import dbus
    import dbus.service
    import dbus.mainloop.glib

    BLUEZ   = 'org.bluez'
    AGENT   = 'org.bluez.Agent1'
    MANAGER = 'org.bluez.AgentManager1'
    PATH    = '/io/nix/btAgent'
    CAP     = 'DisplayYesNo'

    def device_name(bus, path):
        try:
            obj   = bus.get_object(BLUEZ, path)
            props = dbus.Interface(obj, 'org.freedesktop.DBus.Properties')
            return str(props.Get('org.bluez.Device1', 'Name'))
        except Exception:
            return str(path).split('/')[-1]

    class Agent(dbus.service.Object):
        def __init__(self, bus, path):
            dbus.service.Object.__init__(self, bus, path)
            self._bus = bus

        @dbus.service.method(AGENT, in_signature="", out_signature="")
        def Release(self): pass

        @dbus.service.method(AGENT, in_signature="os", out_signature="")
        def AuthorizeService(self, device, uuid): pass

        @dbus.service.method(AGENT, in_signature="o", out_signature="")
        def RequestAuthorization(self, device): pass

        @dbus.service.method(AGENT, in_signature="", out_signature="")
        def Cancel(self): pass

        @dbus.service.method(AGENT, in_signature="ou", out_signature="")
        def RequestConfirmation(self, device, passkey):
            name = device_name(self._bus, device)
            dlg = Gtk.MessageDialog(
                message_type=Gtk.MessageType.QUESTION,
                buttons=Gtk.ButtonsType.YES_NO,
                text=f'Pair with {name}?',
                secondary_text=f'Confirm passkey: {passkey:06d}',
            )
            dlg.set_keep_above(True)
            resp = dlg.run()
            dlg.destroy()
            if resp != Gtk.ResponseType.YES:
                raise dbus.exceptions.DBusException(
                    'org.bluez.Error.Rejected', 'Rejected by user')

        @dbus.service.method(AGENT, in_signature="ouq", out_signature="")
        def DisplayPasskey(self, device, passkey, entered):
            name = device_name(self._bus, device)
            dlg = Gtk.MessageDialog(
                message_type=Gtk.MessageType.INFO,
                buttons=Gtk.ButtonsType.OK,
                text=f'Pairing with {name}',
                secondary_text=f'Passkey: {passkey:06d}',
            )
            dlg.set_keep_above(True)
            dlg.show()

        @dbus.service.method(AGENT, in_signature="os", out_signature="")
        def DisplayPinCode(self, device, pincode):
            name = device_name(self._bus, device)
            dlg = Gtk.MessageDialog(
                message_type=Gtk.MessageType.INFO,
                buttons=Gtk.ButtonsType.OK,
                text=f'Pairing with {name}',
                secondary_text=f'PIN: {pincode}',
            )
            dlg.set_keep_above(True)
            dlg.show()

        @dbus.service.method(AGENT, in_signature="o", out_signature="s")
        def RequestPinCode(self, device):
            name = device_name(self._bus, device)
            dlg = Gtk.Dialog(title=f'PIN for {name}')
            dlg.set_keep_above(True)
            dlg.add_button('OK', Gtk.ResponseType.OK)
            dlg.add_button('Cancel', Gtk.ResponseType.CANCEL)
            box = dlg.get_content_area()
            box.set_spacing(8)
            box.set_margin_top(12)
            box.set_margin_bottom(8)
            box.set_margin_start(12)
            box.set_margin_end(12)
            box.add(Gtk.Label(label=f'Enter PIN for {name}:'))
            entry = Gtk.Entry()
            entry.connect('activate', lambda _: dlg.response(Gtk.ResponseType.OK))
            box.add(entry)
            dlg.show_all()
            resp = dlg.run()
            pin = entry.get_text()
            dlg.destroy()
            if resp != Gtk.ResponseType.OK or not pin:
                raise dbus.exceptions.DBusException(
                    'org.bluez.Error.Rejected', 'Rejected by user')
            return pin

        @dbus.service.method(AGENT, in_signature="o", out_signature="u")
        def RequestPasskey(self, device):
            pin = self.RequestPinCode(device)
            try:
                return dbus.UInt32(int(pin))
            except ValueError:
                return dbus.UInt32(0)

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus   = dbus.SystemBus()
    agent = Agent(bus, PATH)
    mgr   = dbus.Interface(bus.get_object(BLUEZ, '/org/bluez'), MANAGER)
    mgr.RegisterAgent(PATH, CAP)
    mgr.RequestDefaultAgent(PATH)
    GLib.MainLoop().run()
  '';

in
{
  home.packages = [
    (pkgs.writeShellScriptBin "bt-agent" ''
      export GI_TYPELIB_PATH="${giPath}:/run/current-system/sw/lib/girepository-1.0"
      exec ${py}/bin/python3 ${script}
    '')
  ];
}
