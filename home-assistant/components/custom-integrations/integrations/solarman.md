# Solis inverter (Solarman)

The [ha-solarman](https://github.com/davidrapan/ha-solarman) custom
integration (`solarman`) reads the inverter locally (no cloud). Custom inverter
definitions in `custom_components/solarman/inverter_definitions/custom` are
preserved when the version is bumped.

## Setup

The integration is configured through the UI, the device cannot be added in
`configuration.yaml`.

Tested with a Solis S6 hybrid inverter connected to the network over Modbus
TCP (port 502):

1. Give the inverter a static DHCP lease.
2. In Home Assistant: Settings, Devices & services, Add integration,
   "Solarman". Enter the IP address, and select:
   - Transport: `modbus_tcp`
   - Port: `502`
   - Slave ID: `1`
   - Profile: `solis_hybrid.yaml`

   There is no serial number field in this mode. The serial number is only
   needed (and discovered over UDP port 48899) for the Solarman V5 `tcp`
   transport used with Wi-Fi logger sticks.
3. Check that the pod can reach the inverter:
   `kubectl -n home-assistant exec deploy/home-assistant -- nc -zv <ip> 502`.

The bundled `solis_s6-gr1p.yaml` profile uses the legacy 3xxx registers, which
this inverter rejects. The 33xxx register map of `solis_hybrid.yaml` works.

The Modbus server of the inverter only serves one client at a time. Do not run
other Modbus tools against it while Home Assistant is connected.

## Energy dashboard

Use the sensors of the inverter device for the solar production entry. Pick
the lifetime production energy sensor (`sensor.solis_total_production`, a
`total_increasing` kWh sensor), not the daily one, so the long-term statistics
stay correct.

Grid consumption and return are configured separately and do not come from
the inverter (unless a meter is attached to the inverter and exposed by the
profile).
