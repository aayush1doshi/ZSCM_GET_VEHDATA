# Functional Specification

**Subject:** Extension of `ZSCM_GET_VEHDATA` — expose `OIC_LIFNR` in vehicle output  
**Function Module:** `ZSCM_GET_VEHDATA`  
**Version:** 1.0  
**Status:** Draft  
**Related:** DOI `DOI_ZSCM_GET_VEHDATA_OIC_LIFNR.md`, AC `AC_ZSCM_GET_VEHDATA_OIC_LIFNR.md`

---

## 1. Purpose

This document specifies the functional behaviour required when the vehicle data retrieval function module `ZSCM_GET_VEHDATA` is extended so that the vendor-related field `OIC_LIFNR` from custom table `YTTSTX0001` is included in the data returned to callers via `ET_VEHICLE_DATA`.

---

## 2. Scope

### 2.1 In scope

- Returning `OIC_LIFNR` for each vehicle row in `ET_VEHICLE_DATA` when source data contains a value.
- Returning a blank `OIC_LIFNR` when the source field is empty, without errors.
- Preserving all existing filtering, configuration, vendor name resolution (`NAME1` from `LFA1` via `TRANSPTRCD`), messages, and exceptions.

### 2.2 Out of scope

- Changing which vehicles are selected (database `WHERE` clause and Step 4 in-memory filters remain as today).
- Changing function module import parameters or exception set.
- Updating downstream consumers (programs, interfaces, reports) to display or use `OIC_LIFNR` — assessment remains with consuming teams.

---

## 3. Business context

Vehicle master/detail data for supply chain scenarios is stored in `YTTSTX0001`. The function module reads this table according to active entries in `ZLOG_EXEC_VAR` for the function module name `ZSCM_GET_VEHDATA`, applies configured and in-memory filters, enriches rows with vendor name from `LFA1`, and returns a structured table to callers.

The field `OIC_LIFNR` already exists on `YTTSTX0001` and represents OIC-related vendor identification data that callers need alongside existing attributes (area, truck, transport partner, dates/times, etc.). Today that field is not read or returned; this change makes it available in the standard output structure.

---

## 4. Actors and interfaces

| Actor | Role |
|--------|------|
| Calling program / RFC client | Supplies `IM_DATA` (including mandatory `AREA`); reads `ET_VEHICLE_DATA` and `LW_MSG`; handles exceptions. |
| Configuration (basis/functional) | Maintains `ZLOG_EXEC_VAR` for `ZSCM_GET_VEHDATA`. |

No new parameters or RFC metadata are introduced at the functional interface level; only the line type of `ET_VEHICLE_DATA` gains an additional component.

---

## 5. Functional requirements

| ID | Requirement |
|----|----------------|
| FR-01 | For every row returned in `ET_VEHICLE_DATA` that originates from a `YTTSTX0001` row passing current selection and filter rules, the component `OIC_LIFNR` SHALL reflect the value stored in `YTTSTX0001-OIC_LIFNR` for that source row (exact value, no unintended truncation or conversion). |
| FR-02 | If `YTTSTX0001-OIC_LIFNR` is blank for a returned row, `ET_VEHICLE_DATA-OIC_LIFNR` SHALL be blank and the function module SHALL NOT raise an exception or dump solely for that reason. |
| FR-03 | All fields that were returned before this change (including `NAME1` from `LFA1`) SHALL continue to be populated as today under the same inputs and data conditions (regression). |
| FR-04 | Exception behaviour SHALL remain: `INVALID_INPUT` when area is initial; `NO_CONFIGURATION_FOUND` when configuration is missing or incomplete; `DATABASE_ERROR` on handled DB failures; `NO_VEHICLE` when no DB rows; warning and `RETURN` when rows exist but none pass Step 4 filters. |
| FR-05 | The public meaning of `OIC_LIFNR` for consumers SHALL be the same as the dictionary definition on `YTTSTX0001` (same data element as on the table). |

---

## 6. Processing summary (behavioural)

1. **Input validation:** Unchanged — `IM_DATA-AREA` mandatory.
2. **Configuration:** Unchanged — load from `ZLOG_EXEC_VAR` for `ZSCM_GET_VEHDATA`.
3. **Database read:** Vehicle rows are read from `YTTSTX0001` with the same join keys as today; the result set SHALL additionally include `OIC_LIFNR` per row.
4. **In-memory filter:** Unchanged — truck type vs remarks, blank shipping number, blank reject reason; vendor range for `LFA1` still built from `TRANSPTRCD`.
5. **Output build:** Filtered rows are mapped into `ZSCM_S_VEHICLE_OUTPUT`; `OIC_LIFNR` SHALL be carried by the same mapping mechanism as other shared field names (corresponding move), without a separate explicit assignment for this field in application code.
6. **Success path:** Row count and messaging behaviour for success SHALL remain consistent with pre-change behaviour aside from the presence of `OIC_LIFNR` on each line.

---

## 7. Data dictionary (functional)

| Logical item | Description |
|--------------|-------------|
| `OIC_LIFNR` | OIC vendor number (or equivalent) on the vehicle record; sourced from `YTTSTX0001`; exposed on export structure line type `ZSCM_S_VEHICLE_OUTPUT`. Semantics and display format follow the ABAP Dictionary element used on `YTTSTX0001`. |

---

## 8. Traceability to acceptance criteria

| AC reference | Functional coverage |
|--------------|---------------------|
| AC-01, AC-02 | Output structure and table type expose `OIC_LIFNR` with correct typing. |
| AC-03–AC-04 | Program definitions and SELECT list include `OIC_LIFNR` without broadening the query. |
| AC-05, AC-06 | Populated and blank source values both behave correctly in `ET_VEHICLE_DATA`. |
| AC-07 | Mapping approach is correspondence-based, not ad hoc assignment. |
| AC-08, AC-09 | Regression on fields and exceptions. |
| AC-10 | Transport completeness for dependent objects. |

---

## 9. Assumptions and dependencies

- `OIC_LIFNR` exists on `YTTSTX0001` in all target systems before transport.
- Dictionary alignment: `ZSCM_S_VEHICLE_OUTPUT-OIC_LIFNR` uses the same data element as `YTTSTX0001-OIC_LIFNR`.
- Consumers that need to show or validate `OIC_LIFNR` may require separate changes outside this initiative.

---

*End of Functional Specification*
