import Adw from 'gi://Adw';
import Gdk from 'gi://Gdk';
import Gio from 'gi://Gio';
import Cairo from 'gi://cairo';
import Gtk from 'gi://Gtk';

import {PAL, drawIcon, drawText} from './pixelfont.js';
import {ExtensionPreferences} from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

export default class BlackBreakPrefs extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        const css = new Gtk.CssProvider();
        css.load_from_string(`
            window, .background { background-color: #04042c; color: #f4f0e0; font-family: monospace; font-weight: bold; }
            headerbar { background-color: #1c1c6c; border-bottom: 3px solid #5c5cfc; border-radius: 0; box-shadow: none; }
            preferencesgroup label.heading, preferencesgroup label.title-4, preferencesgroup .title-4 { color: #fcc030; font-size: 13pt; }
            preferencesgroup label.dim-label, preferencesgroup .subtitle { color: #8c88a8; }
            list.boxed-list, .card { background-color: #0d0c0b; border: 3px solid #5c5cfc; border-radius: 0; box-shadow: 4px 4px 0 #000000; }
            row, row:hover, row:active { background-color: #0d0c0b; border-radius: 0; }
            row { border-bottom: 2px solid #1c1c6c; }
            row title, row .title { color: #f4f0e0; }
            entry, text { background-color: #04042c; color: #fcc030; border-radius: 0; }
            switch { background-color: #1d2a1d; border: 2px solid #5c5cfc; border-radius: 0; min-width: 52px; }
            switch:checked { background-color: #30c030; border-color: #fcc030; }
            switch slider { background-color: #f4f0e0; background-image: none; border-radius: 0; border: 2px solid #000000; min-width: 22px; min-height: 22px; }
        `);
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        const settings = this.getSettings();
        window._settings = settings; // keep it alive with the window
        const page = new Adw.PreferencesPage();
        // a banner: the eye, the name, and what the app is
        const banner = new Gtk.DrawingArea({content_height: 80, margin_top: 12, margin_bottom: 6});
        banner.set_draw_func((_a, cr, w) => {
            cr.setAntialias(Cairo.Antialias.NONE);
            drawIcon(cr, 12, 8, 4);
            drawText(cr, 'BlackBreak', 92, 10, 4, PAL.gold);
            drawText(cr, '30 s every 20 min. no skip.', 92, 52, 2, PAL.dim);
        });
        const bannerGroup = new Adw.PreferencesGroup();
        bannerGroup.add(banner);
        page.add(bannerGroup);
        const group = new Adw.PreferencesGroup({
            title: 'Calls',
            description: 'A break waits at most 3 hours.',
        });
        page.add(group);

        const main = new Adw.SwitchRow({title: "Wait with the break while I'm in a call"});
        settings.bind('call-exemption', main, 'active', Gio.SettingsBindFlags.DEFAULT);
        group.add(main);

        for (const [key, title] of [['exempt-mic', 'Microphone in use'],
            ['exempt-camera', 'Camera in use']]) {
            const row = new Adw.SwitchRow({title});
            settings.bind(key, row, 'active', Gio.SettingsBindFlags.DEFAULT);
            settings.bind('call-exemption', row, 'sensitive', Gio.SettingsBindFlags.GET);
            group.add(row);
        }

        const busy = new Adw.PreferencesGroup({
            title: 'Busy',
            description: 'The break waits (3 hours at most) while one of these is going on.',
        });
        page.add(busy);
        const full = new Adw.SwitchRow({title: 'A fullscreen window is in focus (games, video)'});
        settings.bind('exempt-fullscreen', full, 'active', Gio.SettingsBindFlags.DEFAULT);
        busy.add(full);
        const appOn = new Adw.SwitchRow({title: 'A chosen app is in focus'});
        settings.bind('exempt-app-on', appOn, 'active', Gio.SettingsBindFlags.DEFAULT);
        busy.add(appOn);
        const appRow = new Adw.ActionRow({title: 'App'});
        const show = () => {
            const id = settings.get_strv('exempt-apps')[0];
            appRow.subtitle = id ? (Gio.DesktopAppInfo.new(id)?.get_display_name() ?? id) : 'none chosen';
        };
        show();
        const pick = new Gtk.Button({label: 'Choose...', valign: Gtk.Align.CENTER});
        pick.connect('clicked', () => {
            const dlg = new Gtk.AppChooserDialog({transient_for: window, modal: true});
            dlg.connect('response', (_d, resp) => {
                const info = resp === Gtk.ResponseType.OK ? dlg.get_app_info() : null;
                if (info) {
                    settings.set_strv('exempt-apps', [info.get_id()]);
                    show();
                }
                dlg.destroy();
            });
            dlg.show();
        });
        appRow.add_suffix(pick);
        settings.bind('exempt-app-on', appRow, 'sensitive', Gio.SettingsBindFlags.GET);
        busy.add(appRow);


        const more = new Adw.PreferencesGroup({title: 'Reminders'});
        page.add(more);
        const warn = new Adw.SwitchRow({title: 'Show "Break in 10 s" before a break'});
        settings.bind('show-warning', warn, 'active', Gio.SettingsBindFlags.DEFAULT);
        more.add(warn);
        const snd = new Adw.SwitchRow({title: 'Soft sound when a break ends'});
        settings.bind('end-sound', snd, 'active', Gio.SettingsBindFlags.DEFAULT);
        more.add(snd);

        const today = new Adw.PreferencesGroup({title: 'Today'});
        page.add(today);
        const d = new Date();
        const p2 = n => String(n).padStart(2, '0');
        const key = `${d.getFullYear()}-${p2(d.getMonth() + 1)}-${p2(d.getDate())}`;
        const count = settings.get_string('stats-day') === key ? settings.get_int('stats-breaks') : 0;
        today.add(new Adw.ActionRow({title: 'Breaks taken', subtitle: String(count)}));

        window.add(page);
        window.connect('close-request', () =>
            Gtk.StyleContext.remove_provider_for_display(Gdk.Display.get_default(), css));
    }
}
