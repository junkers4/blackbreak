import Adw from 'gi://Adw';
import Gio from 'gi://Gio';
import {ExtensionPreferences} from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

export default class BlackBreakPrefs extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        const settings = this.getSettings();
        window._settings = settings; // keep it alive with the window
        const page = new Adw.PreferencesPage();
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
        window.add(page);
    }
}
