# Spot price

Adds template sensors on top of the core
[Nord Pool](https://www.home-assistant.io/integrations/nordpool/) integration,
for cost and compensation tracking in the Energy dashboard.

The package `spot_price.yaml` is mounted into `/config/packages` and defines:

- `sensor.electricity_buy_price` (EUR/kWh): `spot + margin`.
- `sensor.electricity_sell_price` (EUR/kWh): `spot - margin`.

## Setup

1. In Home Assistant: Settings, Devices & services, Add integration,
   "Nord Pool". Select area `FI` and currency `EUR`. No API key is needed.
2. In the Energy dashboard, for both grid consumption and return to grid, pick
   "Use an entity with current price" and select the buy price for
   consumption and the sell price for return.
