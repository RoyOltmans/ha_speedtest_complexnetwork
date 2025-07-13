# HA SpeedTest (Command-Line Version)

> **Warning:** This setup is intended for advanced or complex network environments. Ensure you have the Speedtest CLI installed, a valid custom server ID, and correct script permissions before proceeding.

## Overview

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
     name: speedtest_host
     command: "/config/scripts/hass_speedtest.sh"
     scan_interval: 3600      # seconds between tests (adjust as needed)
     value_template: "{{ value_json.timestamp }}"
     json_attributes:
       - server
       - ping
       - download
       - upload
       - packetLoss
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

## Troubleshooting

* **No data**: Check the script path, executable bits, and that Speedtest CLI runs manually without errors.
* **Permission denied**: Adjust file ownership or permissions so Home Assistant can execute the script.
* **Test failures or timeouts**: Increase the timeout in `hass_speedtest.sh` or lengthen `scan_interval`.

```
```
