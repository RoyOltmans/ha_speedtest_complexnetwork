# HA SpeedTest (Command-Line Version)

> **Warning:** This setup is intended for advanced or complex network environments. Ensure you have the Speedtest CLI installed, a valid custom server ID, and correct script permissions before proceeding.

## Overview

This setup relies on the official Speedtest CLI tool; for detailed usage and advanced options, refer to its manual page (`man speedtest`) or the [official Speedtest CLI documentation](https://www.speedtest.net/apps/cli).

Instead of a custom component, this approach uses Home Assistant's built-in `command_line` sensor to run a Bash script (`hass_speedtest.sh`) that executes Speedtest CLI, caches JSON output, and then leverages template sensors to extract individual metrics (download, upload, ping, packet loss, host info).

## Files

- **hass_speedtest.sh**: Bash script (provided) that runs the Speedtest CLI and caches the result.
- **command_line.yaml**: Contains the `command_line` sensor definition.
- **sensors.yaml**: Contains `template` sensors to flatten JSON attributes.

## Installation

### Install Speedtest CLI

Before using the script, install the official Speedtest CLI for your OS using its native package manager:

**Debian / Raspbian (Bullseye)**
```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://packagecloud.io/ookla/speedtest-cli/gpgkey \
  | gpg --dearmor \
  | sudo tee /etc/apt/keyrings/ookla_speedtest-cli-archive-keyring.gpg >/dev/null

echo \
"deb [signed-by=/etc/apt/keyrings/ookla_speedtest-cli-archive-keyring.gpg] \
https://packagecloud.io/ookla/speedtest-cli/debian/ bullseye main" \
| sudo tee /etc/apt/sources.list.d/ookla_speedtest.list

sudo apt-get update
sudo apt-get install speedtest
```bash
curl -s https://install.speedtest.net/app/cli/install.deb.sh | sudo bash
sudo apt-get update
sudo apt-get install speedtest
````

**Ubuntu**

```bash
curl -s https://install.speedtest.net/app/cli/install.deb.sh | sudo bash
sudo apt update
sudo apt install speedtest
```

**Fedora**

```bash
wget -O speedtest.rpm https://install.speedtest.net/app/cli/ookla-speedtest-*-x86_64.rpm
sudo dnf install speedtest.rpm
```

---

1. **Copy the SpeedTest script**
   Place `hass_speedtest.sh` into your Home Assistant config directory (e.g. `/config/scripts/`):

   ```bash
   cp hass_speedtest.sh /config/scripts/hass_speedtest.sh
   chmod +x /config/scripts/hass_speedtest.sh
   ```

2. **Create `command_line.yaml`**
   In your config folder, create `command_line.yaml` with:

   ```yaml
   - platform: command_line
     name: Speedtest host
     scan_interval:
       minutes: 60
     command: cat /config/.last_speedtest.json
     value_template: "{{ value_json.isp }}"
     json_attributes:
       - server
       - ping
       - download
       - upload
       - packetLoss
   ```

   This sensor reads the JSON cache output written by your speedtest script. To schedule it automatically, add a cron job:

3. **Open your crontab** (runs as the Home Assistant user):

   ```bash
   # If Home Assistant runs as 'homeassistant' user:
   sudo crontab -u homeassistant -e
   # Otherwise, for your current user:
   crontab -e
   ```

4. **Add the following line** at the end of the file:

   ```cron
   */60 * * * * /opt/home-assistant/hass_speedtest.sh >/dev/null 2>&1
   ```

5. **Save and exit** your editor (e.g., `Ctrl+O`, `Enter`, `Ctrl+X` in nano).

Now cron will run the script every hour and update `/config/.last_speedtest.json`.

```bash
   # Run every hour
   */60 * * * * /opt/home-assistant/hass_speedtest.sh >/dev/null 2>&1
```

3. **Place your `sensors.yaml`**
   Use the provided `sensors.yaml` (adjust paths or names if required):

   ```yaml
   - platform: template
     sensors:
       speedtest_host_server:
         value_template: >-
           {{ state_attr('sensor.speedtest_host','server').name }} - {{ state_attr('sensor.speedtest_host','server').location }}
       speedtest_host_idle_latency:
         value_template: >-
           {{ state_attr('sensor.speedtest_host','ping').latency | round(2) }}
         unit_of_measurement: "ms"
       speedtest_host_download:
         value_template: >-
           {{ (state_attr('sensor.speedtest_host','download').bandwidth * 8 / 1e6) | round(2) }}
         unit_of_measurement: "Mbps"
       speedtest_host_upload:
         value_template: >-
           {{ (state_attr('sensor.speedtest_host','upload').bandwidth * 8 / 1e6) | round(2) }}
         unit_of_measurement: "Mbps"
       speedtest_host_packet_loss:
         value_template: >-
           {{ state_attr('sensor.speedtest_host','packetLoss') | default(0) }}
         unit_of_measurement: "%"
   ```

4. **Include in your `configuration.yaml`**

   ```yaml
   command_line: !include command_line.yaml
   sensor: !include sensors.yaml
   ```

5. **Restart Home Assistant**
   Navigate to **Settings → System → Restart**.

## Configuration Notes

### Cache File Location

The script writes its JSON output cache to the path defined by the `CACHE` variable in `hass_speedtest.sh`. By default this example uses:

```bash
CACHE="/opt/home-assistant/.last_speedtest.json"
```

Adjust this path to match your Home Assistant installation type:

* **Home Assistant OS / Container**: `/config/.last_speedtest.json`
* **Supervised / Hass.io on Raspbian**: `/usr/share/hassio/homeassistant/.last_speedtest.json`
* **Python virtualenv / pip install**: `/home/homeassistant/.homeassistant/.last_speedtest.json`
* **Debian package (`apt install homeassistant`)**: `/opt/homeassistant/.last_speedtest.json`
* **Hassbian image**: `/home/homeassistant/.homeassistant/.last_speedtest.json`

Make sure the directory exists and is writable by the user running Home Assistant.

## Configuration Notes

* **Script path**: If you place `hass_speedtest.sh` elsewhere, update the `command` path accordingly.
* **Speedtest CLI**: Must be installed and accessible at the path defined in `hass_speedtest.sh`.
* **Server ID**: The default server ID (`61186`) lives in the script—modify it to use a different Speedtest server.
* **Permissions**: Ensure the user running Home Assistant can execute the script and write to the cache location.
* **Scan interval**: Adjust to balance freshness versus rate limits or load.

## Entities Available

After restart, you should see:

* `sensor.speedtest_host_server`
* `sensor.speedtest_host_idle_latency`
* `sensor.speedtest_host_download`
* `sensor.speedtest_host_upload`
* `sensor.speedtest_host_packet_loss`

## Example Lovelace Card

```yaml
type: entities
title: Internet Speed (CLI)
entities:
  - sensor.speedtest_host_server
  - sensor.speedtest_host_idle_latency
  - sensor.speedtest_host_download
  - sensor.speedtest_host_upload
  - sensor.speedtest_host_packet_loss
```

## Dashboard Configuration

Use the snippet below as your `dashboard.yaml`. It can be pasted directly into the YAML editor for your Speedtest view:

```yaml
title: Speedtest
path: speedtest
icon: mdi:speedometer
cards:
  - type: vertical-stack
    cards:
      - type: picture
        image: /local/assets/images/brands/speedtest.png
      - type: markdown
        content: >-
          <ha-icon icon="mdi:server-network"></ha-icon> **ISP - Server:** {{ state_attr('sensor.speedtest_host','server').name }} – {{ state_attr('sensor.speedtest_host','server').location }}

          <ha-icon icon="mdi:timer"></ha-icon> **Idle Latency:** {{ states('sensor.speedtest_host_idle_latency') }} ms

          <ha-icon icon="mdi:chart-bell-curve"></ha-icon> **Packet Loss:** {{ states('sensor.speedtest_host_packet_loss') }} %
        text_only: true
      - type: vertical-stack
        view_layout:
          width: 10
          max_cols: 10
        cards:
          - type: horizontal-stack
            cards:
              - type: custom:mini-graph-card
                name: Download
                icon: mdi:download
                entities:
                  - sensor.speedtest_host_download
                hours_to_show: 24
                points_per_hour: 1
                line_width: 2
                font_size: 70
                height: 70
                show:
                  fill: true
                  extrema: true
                color_thresholds:
                  - value: 0
                    color: red
                  - value: 1500
                    color: yellow
                  - value: 1800
                    color: green
              - type: custom:mini-graph-card
                name: Upload
                icon: mdi:upload
                entities:
                  - sensor.speedtest_host_upload
                hours_to_show: 24
                points_per_hour: 1
                line_width: 2
                font_size: 70
                height: 70
                show:
                  fill: true
                  extrema: true
                color_thresholds:
                  - value: 0
                    color: red
                  - value: 600
                    color: yellow
                  - value: 800
                    color: green
      - type: custom:apexcharts-card
        header:
          show: true
          show_states: true
          colorize_states: true
        series:
          - entity: sensor.speedtest_host_download
            name: Download
            stroke_width: 2
          - entity: sensor.speedtest_host_upload
            name: Upload
            stroke_width: 2
```

## Troubleshooting

* **No data**: Check the script path, executable bits, and that Speedtest CLI runs manually without errors.
* **Permission denied**: Adjust file ownership or permissions so Home Assistant can execute the script.
* **Test failures or timeouts**: Increase the timeout in `hass_speedtest.sh` or lengthen `scan_interval`.

```
