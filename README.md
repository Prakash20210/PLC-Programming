# PLC-Programming

## Fuji PLC car parking example

This repository includes a Structured Text car parking control program for Fuji PLCs:

- `fuji_car_parking_program.st`

### Features

- Entry and exit vehicle counting
- Capacity limit enforcement (`MAX_SLOTS`)
- Sensor re-arm logic to reduce double-counting from one vehicle event
- Configurable gate hold-open timing (`GATE_HOLD_TIME`)
- `FULL` / `AVAILABLE` indicator lamps
- `ParkedCars` and `FreeSlots` values for HMI display

### Typical I/O map

- `X0`: Entry sensor
- `X1`: Exit sensor
- `X2`: Reset pushbutton
- `Y0`: Entry gate command
- `Y1`: Exit gate command
- `Y2`: Full lamp
- `Y3`: Available lamp

### Configuration

In `fuji_car_parking_program.st`, tune:

- `MAX_SLOTS` (e.g., `50`)
- `GATE_HOLD_TIME` (e.g., `T#3s`)

Then map variables to your Fuji PLC device addresses (X/Y/M/D) in the programming software.
