# Solis inverter (Solarman)

Installs the [ha-solarman](https://github.com/davidrapan/ha-solarman) custom
integration (`solarman`) with an init container into
`/config/custom_components`. It reads the inverter locally (no cloud) through
the Solarman V5 protocol of the Wi-Fi datalogger stick, and also supports
Modbus TCP gateways. Custom inverter definitions in
`custom_components/solarman/inverter_definitions/custom` are preserved when the
version is bumped.

## Setup

The integration is configured through the UI, the device cannot be added in
`configuration.yaml`.

1. Give the datalogger a static DHCP lease.
2. Find the logger serial number. It is printed on the stick and shown in the
   SolisCloud/Solarman app.
3. In Home Assistant: Settings, Devices & services, Add integration,
   "Solarman". Enter the IP address and the logger serial number. The
   integration tries to detect the inverter profile automatically.
4. If auto detection fails, pick a Solis profile manually: `solis_1p-5g`
   (single phase), `solis_3p-4g` or `solis_3p-5g` (three phase),
   `solis_hybrid` or `solis_s6-gr1p`.
5. Check that the pod can reach the logger (the Solarman V5 protocol uses TCP
   port 8899):
   `kubectl -n home-assistant exec deploy/home-assistant -- nc -zv <ip> 8899`.

## Energy dashboard

Use the sensors of the inverter device for the solar production entry. Pick
the lifetime production energy sensor (a `total_increasing` kWh sensor), not
the daily one, so the long-term statistics stay correct.

Grid consumption and return are configured separately and do not come from
the inverter (unless a meter is attached to the inverter and exposed by the
profile).
