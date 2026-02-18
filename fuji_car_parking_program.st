(***
  Fuji PLC Car Parking Program (Structured Text)
  ------------------------------------------------
  Description:
  - Counts vehicles entering and leaving a parking lot.
  - Opens entry barrier only when parking is not full.
  - Opens exit barrier whenever a vehicle is detected at exit.
  - Drives FULL lamp and exposes free slots.

  Capacity can be changed using MAX_SLOTS.

  Suggested I/O mapping on Fuji PLC:
  Inputs
    X0 : Entry vehicle sensor (photoelectric/loop)
    X1 : Exit vehicle sensor  (photoelectric/loop)
    X2 : System reset pushbutton
  Outputs
    Y0 : Entry barrier open solenoid/motor command
    Y1 : Exit barrier open solenoid/motor command
    Y2 : Parking FULL indicator lamp
    Y3 : Parking AVAILABLE indicator lamp

  Internal registers / variables can be mapped to D/M as needed in Fuji Workbench.
***)

PROGRAM CAR_PARKING
VAR
    (* Constants / settings *)
    MAX_SLOTS : INT := 50;          (* Total parking capacity *)

    (* Digital inputs *)
    EntrySensor : BOOL;             (* X0 *)
    ExitSensor  : BOOL;             (* X1 *)
    ResetPB     : BOOL;             (* X2 *)

    (* Digital outputs *)
    EntryGateCmd : BOOL;            (* Y0 *)
    ExitGateCmd  : BOOL;            (* Y1 *)
    FullLamp     : BOOL;            (* Y2 *)
    AvailLamp    : BOOL;            (* Y3 *)

    (* Internal states *)
    ParkedCars : INT := 0;
    FreeSlots  : INT := 50;
    IsFull     : BOOL;

    (* Rising-edge helper bits *)
    PrevEntrySensor : BOOL := FALSE;
    PrevExitSensor  : BOOL := FALSE;
    EntryPulse      : BOOL;
    ExitPulse       : BOOL;
END_VAR

(* 1) Edge detection so one car increments/decrements once per sensor event *)
EntryPulse := EntrySensor AND NOT PrevEntrySensor;
ExitPulse  := ExitSensor  AND NOT PrevExitSensor;

(* 2) Reset logic *)
IF ResetPB THEN
    ParkedCars := 0;
END_IF;

(* 3) Car count logic with range protection *)
IF EntryPulse AND (ParkedCars < MAX_SLOTS) THEN
    ParkedCars := ParkedCars + 1;
END_IF;

IF ExitPulse AND (ParkedCars > 0) THEN
    ParkedCars := ParkedCars - 1;
END_IF;

(* 4) Derive status flags *)
IsFull := (ParkedCars >= MAX_SLOTS);
FreeSlots := MAX_SLOTS - ParkedCars;

(* 5) Barrier control *)
(* Open entry gate only for incoming car when not full *)
EntryGateCmd := EntrySensor AND NOT IsFull;

(* Open exit gate when car is present at exit sensor *)
ExitGateCmd := ExitSensor;

(* 6) Indicators *)
FullLamp  := IsFull;
AvailLamp := NOT IsFull;

(* 7) Store previous states for edge detection *)
PrevEntrySensor := EntrySensor;
PrevExitSensor  := ExitSensor;

END_PROGRAM
