(***
  Fuji PLC Car Parking Program (Structured Text)
  ------------------------------------------------
  Description:
  - Counts vehicles entering and leaving a parking lot.
  - Rejects new entry count while the lot is full.
  - Uses sensor re-arm logic to avoid multiple counts while one car remains in beam.
  - Provides configurable gate hold-open timers.
  - Drives FULL/AVAILABLE lamps and exposes free-slot value.

  Tune these settings for your site:
    MAX_SLOTS      : lot capacity
    GATE_HOLD_TIME : gate open time after a valid detection
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
    Y0 : Entry barrier open command
    Y1 : Exit barrier open command
    Y2 : Parking FULL indicator lamp
    Y3 : Parking AVAILABLE indicator lamp

  Note:
  - Map BOOL/INT variables to Fuji device addresses (X/Y/M/D) in your project.
    Y0 : Entry barrier open solenoid/motor command
    Y1 : Exit barrier open solenoid/motor command
    Y2 : Parking FULL indicator lamp
    Y3 : Parking AVAILABLE indicator lamp

  Internal registers / variables can be mapped to D/M as needed in Fuji Workbench.
***)

PROGRAM CAR_PARKING
VAR
    (* ===== Settings ===== *)
    MAX_SLOTS      : INT  := 50;      (* Total parking capacity *)
    GATE_HOLD_TIME : TIME := T#3s;    (* Gate hold-open duration *)

    (* ===== Inputs ===== *)
    EntrySensor : BOOL;               (* X0 *)
    ExitSensor  : BOOL;               (* X1 *)
    ResetPB     : BOOL;               (* X2 *)

    (* ===== Outputs ===== *)
    EntryGateCmd : BOOL;              (* Y0 *)
    ExitGateCmd  : BOOL;              (* Y1 *)
    FullLamp     : BOOL;              (* Y2 *)
    AvailLamp    : BOOL;              (* Y3 *)

    (* ===== Internal process data ===== *)
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

    (* Sensor edge / re-arm logic *)
    (* Rising-edge helper bits *)
    PrevEntrySensor : BOOL := FALSE;
    PrevExitSensor  : BOOL := FALSE;
    EntryPulse      : BOOL;
    ExitPulse       : BOOL;
    EntryArmed      : BOOL := TRUE;
    ExitArmed       : BOOL := TRUE;

    (* Gate hold timers *)
    EntryGateTON : TON;
    ExitGateTON  : TON;
    EntryGateReq : BOOL := FALSE;
    ExitGateReq  : BOOL := FALSE;
END_VAR

(* 1) Rising-edge detection *)
EntryPulse := EntrySensor AND NOT PrevEntrySensor;
ExitPulse  := ExitSensor  AND NOT PrevExitSensor;

(* 2) Reset count when requested *)
END_VAR

(* 1) Edge detection so one car increments/decrements once per sensor event *)
EntryPulse := EntrySensor AND NOT PrevEntrySensor;
ExitPulse  := ExitSensor  AND NOT PrevExitSensor;

(* 2) Reset logic *)
IF ResetPB THEN
    ParkedCars := 0;
END_IF;

(* 3) Re-arm logic:
      - Arm is cleared after first rising edge.
      - Arm is set again only when sensor goes fully OFF.
      This helps avoid repeated counts from one vehicle dwell/chatter. *)
IF NOT EntrySensor THEN
    EntryArmed := TRUE;
END_IF;

IF NOT ExitSensor THEN
    ExitArmed := TRUE;
END_IF;

(* 4) Counting logic with bounds and full protection *)
IF EntryPulse AND EntryArmed AND (ParkedCars < MAX_SLOTS) THEN
    ParkedCars := ParkedCars + 1;
    EntryArmed := FALSE;
    EntryGateReq := TRUE;
END_IF;

IF ExitPulse AND ExitArmed AND (ParkedCars > 0) THEN
    ParkedCars := ParkedCars - 1;
    ExitArmed := FALSE;
    ExitGateReq := TRUE;
END_IF;

(* 5) Derived status *)
IF ParkedCars < 0 THEN
    ParkedCars := 0;
END_IF;
IF ParkedCars > MAX_SLOTS THEN
    ParkedCars := MAX_SLOTS;
END_IF;

IsFull := (ParkedCars >= MAX_SLOTS);
FreeSlots := MAX_SLOTS - ParkedCars;

(* 6) Gate control using hold-open timers
      Request bit starts timer; timer keeps gate open for GATE_HOLD_TIME. *)
EntryGateTON(IN := EntryGateReq, PT := GATE_HOLD_TIME);
ExitGateTON(IN := ExitGateReq, PT := GATE_HOLD_TIME);

EntryGateCmd := EntryGateTON.Q;
ExitGateCmd  := ExitGateTON.Q;

(* Auto-clear requests when timer done and no new trigger arrived *)
IF EntryGateReq AND EntryGateTON.Q AND EntryGateTON.ET >= GATE_HOLD_TIME THEN
    EntryGateReq := FALSE;
END_IF;
IF ExitGateReq AND ExitGateTON.Q AND ExitGateTON.ET >= GATE_HOLD_TIME THEN
    ExitGateReq := FALSE;
END_IF;

(* 7) Lamps *)
FullLamp  := IsFull;
AvailLamp := NOT IsFull;

(* 8) Store previous scan inputs *)
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
(* Open entry gate for a present vehicle when not full,
   including the transition scan that consumes the final slot. *)
EntryGateCmd := EntrySensor AND ((NOT IsFull) OR EntryPulse);

(* Open exit gate when car is present at exit sensor *)
ExitGateCmd := ExitSensor;

(* 6) Indicators *)
FullLamp  := IsFull;
AvailLamp := NOT IsFull;

(* 7) Store previous states for edge detection *)
PrevEntrySensor := EntrySensor;
PrevExitSensor  := ExitSensor;

END_PROGRAM
