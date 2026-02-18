# PLC-Programming

## Fuji PLC car parking example

This repository now includes a ready-to-use Structured Text car parking control example for Fuji PLCs:

- `fuji_car_parking_program.st`

### What it does

- Counts cars entering/exiting the lot
- Prevents entry when lot is full
- Controls entry/exit gate commands
- Provides `FULL` and `AVAILABLE` lamp outputs
- Exposes `FreeSlots` and `ParkedCars` values for HMI/display

### Typical I/O map

- `X0`: Entry sensor
- `X1`: Exit sensor
- `X2`: Reset pushbutton
- `Y0`: Entry gate command
- `Y1`: Exit gate command
- `Y2`: Full lamp
- `Y3`: Available lamp

You can adjust lot capacity by changing `MAX_SLOTS` in the ST program.
