# XiSMS

A Windower addon for Final Fantasy XI that sends SMS notifications based on in-game events and conditions. Configure custom triggers and receive alerts via SMS using the XiSMS web service.

## Features

- Send SMS notifications for custom in-game conditions (e.g., low HP, job points reached)
- Filter and match chat log messages using wildcards
- Easy configuration via XML
- Supports multiple notification types and conditions
- Simple command interface

## Requirements

- [Windower](https://www.windower.net/)
- Lua 5.1+ (Windower default)
- An account and API key from [XiSMS](https://xisms.app/)

## Installation

1. **Download or clone this repository** into your Windower `addons` directory:
   ```sh
   git clone <repo-url> <Windower>/addons/XiSMS
   ```
2. **Copy the example settings file:**
   ```sh
   cp data/settings.example.xml data/settings.xml
   ```
3. **Edit `data/settings.xml`:**
   - Enter your API key from [XiSMS](https://xisms.app/) in the `<key>` field.
   - Customize notification conditions and messages as needed (see below).

## Updating

To update XiSMS to the latest version, run the following command in your XiSMS addon directory:

```sh
git pull
```

This will fetch and apply the latest changes from the repository. Note that your `settings.xml` will remain untouched as it is excluded.

## Configuration

Edit `data/settings.xml` to set your API key and notification rules. Example:

```xml
<settings>
    <global>
        <key>your_api_key_here</key>
        <tells>on</tells>
        <notifications>
            <when>
                <condition>
                    <!-- eq, gt, lt, gte, lte, ne -->
                    <lt>
                        <!-- property path in the player object -->
                        <var>vitals.hp</var>
                        <val>800</val>
                    </lt>
                </condition>
                <message>HP is below 800!</message>
            </when>
            <when>
                <!-- You can also use a filter to match messages in the log. * is a wildcard. -->
                <filter>Romeo earns a job point! *499*</filter>
                <message>Job Points are at 499!</message>
            </when>
        </notifications>
    </global>
</settings>
```

### Condition-based Notifications

- Supported condition operators: `eq` (equals), `gt` (greater than), `lt` (less than), `gte` (greater than or equal), `lte` (less than or equal), `ne` (not equal)
- Use property paths from the [player object](PLAYER.md) (e.g., `vitals.hp`, `job_points.rdm.jp`)

### Chat Log Filtering

You can filter chat log messages using wildcards in the `<filter>` tag:

- Use `*` as a wildcard to match any sequence of characters
- Examples:
  - `Romeo earns a job point! *499*` - matches job point messages containing "499"
  - `*finds a monster*` - matches any monster discovery message
  - `*obtained*` - matches any message containing "obtained"

The filter is case-sensitive and matches against the raw chat log messages.

## Usage

1. **Load the addon in Windower:**
   ```
   //lua load XiSMS
   ```
2. **Start the SMS listener:**
   ```
   //xsms start
   ```
3. **Stop the SMS listener:**
   ```
   //xsms stop
   ```
4. **Send a test SMS:**
   ```
   //xsms test
   ```
5. **Reload the addon:**
   ```
   //xsms reload
   ```
6. **Dump player object (for advanced users):**
   ```
   //xsms dump
   ```
7. **Reset notification sent flags:**
   ```
   //xsms reset
   ```
8. **Enable SMS on /tell:**
   ```
   //xsms tellson
   ```
9. **Disable SMS on /tell:**
   ```
   //xsms tellsoff
   ```
10. **Show help:**

```
//xsms help
```

## Auto-Loading XiSMS on Startup

To automatically load and start XiSMS when Windower launches, add the following lines to your `Windower/scripts/init.txt` file:

```
lua l xisms
xsms start
```

This ensures XiSMS is loaded and the SMS listener is started every time you launch Windower.

## Command Reference

- `start` — Starts SMS listener
- `stop` — Stops SMS listener
- `reload` — Reloads the addon
- `dump` — Dumps player object as formatted table
- `reset` — Resets the notification sent flag
- `test` — Sends a test SMS
- `tellson` — Enables SMS notifications for /tell messages
- `tellsoff` — Disables SMS notifications for /tell messages
- `help` — Displays help text

## Notes

- The addon uses `lib/dkjson.lua` for JSON encoding (included).
- All configuration is done via `data/settings.xml`.
- You must have a valid API key from [XiSMS](https://xisms.app/).
- Game ID references (e.g., job, emote, chat mode, weather, skill, bag IDs, etc.) can be found at: [Windower Lua Game ID Reference](https://github.com/Windower/Lua/wiki/Game-ID-Reference)

## License

- XiSMS addon: [MIT License](LICENSE.md)
- `lib/dkjson.lua`: Copyright (C) 2010-2024 David Heiko Kolf (MIT License)

---

For support or questions, open an issue or contact the author.
