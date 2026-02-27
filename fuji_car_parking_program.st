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
    ParkedCars : INT := 0;
    FreeSlots  : INT := 50;
    IsFull     : BOOL;

    (* Sensor edge / re-arm logic *)
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
PrevEntrySensor := EntrySensor;
PrevExitSensor  := ExitSensor;

END_PROGRAM
