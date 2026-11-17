# go-e chargers and controller

The [ha-goecharger-api2](https://github.com/marq24/ha-goecharger-api2) custom
integration (`goecharger_api2`, "go-e APIv2 Connect") supports go-eChargers
and the go-eController.

## Setup

The integration is configured through the UI, the devices cannot be added in
`configuration.yaml`. mDNS discovery does not work from the pod network, so add
each device by IP.

1. In the go-e app, enable the local HTTP API v2 on each charger and the
   controller (Settings, Connection, API Settings, "Allow local HTTP API v2").
   Alternatively set a password on the charger to use the WebSocket
   connection, which pushes updates instead of polling (chargers only).
2. Give each device a static DHCP lease (the range starts at `192.168.1.100`).
3. In Home Assistant: Settings, Devices & services, Add integration, "go-e
   APIv2 Connect". Pick go-eCharger or go-eController, enter the IP address
   and an area. Repeat for every device.
4. Check that the pod can reach the device:
   `kubectl -n home-assistant exec deploy/home-assistant -- curl -s "http://<ip>/api/status?filter=car"`.

Many sensors are disabled by default. Enable the ones needed for the Energy
dashboard (total energy, power) in the entity settings.
