# Acceptance Criteria

**Function Module:** `ZSCM_GET_VEHDATA`  
**Change:** Add field `OIC_LIFNR` to `YTTSTX0001` SELECT and FM output  
**Document Status:** Draft  
**Prepared By:** *(Author)*  
**Date:** *(Date)*

---

## AC-01 — Dictionary Structure Updated

**Given** the change is transported to the target system  
**When** `ZSCM_S_VEHICLE_OUTPUT` is inspected in SE11  
**Then:**
- Field `OIC_LIFNR` is present in the structure
- The data element assigned to `OIC_LIFNR` in `ZSCM_S_VEHICLE_OUTPUT` is identical to the data element used for `OIC_LIFNR` in `YTTSTX0001`
- The structure is active with no activation errors

---

## AC-02 — Table Type Inherits New Field

**Given** `ZSCM_S_VEHICLE_OUTPUT` is updated and active  
**When** `ZSCM_TT_VEHICLE_OUTPUT` is inspected in SE11  
**Then:**
- `OIC_LIFNR` is visible as an inherited field in the table type without any direct modification to `ZSCM_TT_VEHICLE_OUTPUT`
- The table type is active with no activation errors

---

## AC-03 — Local Types Extended in Function Group

**Given** the FM source code is reviewed  
**When** the function group include containing `ty_yttstx0001_select` is inspected  
**Then:**
- `OIC_LIFNR` is present as a field in `ty_yttstx0001_select`
- `ty_yttstx0001_table` is defined as `TABLE OF ty_yttstx0001_select` with no separate field addition required
- No syntax errors exist in the function group

---

## AC-04 — SELECT Statement Includes OIC_LIFNR

**Given** the FM source code is reviewed  
**When** the SELECT query on `YTTSTX0001` in Step 3 is inspected  
**Then:**
- `oic_lifnr` is explicitly listed in the named SELECT field list
- `SELECT *` has not been used
- No changes have been made to the WHERE clause, FOR ALL ENTRIES logic, or any existing field in the SELECT list
- The SELECT statement has no syntax errors

---

## AC-05 — OIC_LIFNR Populated in Output — Happy Path

**Given** valid `IM_DATA-AREA` is provided  
**And** matching records exist in `YTTSTX0001` that pass the Step 4 filter (truck type, shnumber blank, reject_res blank)  
**And** those records have `OIC_LIFNR` populated  
**When** the FM is executed in SE37  
**Then:**
- `ET_VEHICLE_DATA` contains rows with `OIC_LIFNR` correctly populated from `YTTSTX0001`
- `OIC_LIFNR` values match the source records exactly — no truncation, no type conversion errors

---

## AC-06 — OIC_LIFNR Blank in Source — No Error

**Given** valid `IM_DATA-AREA` is provided  
**And** matching records exist in `YTTSTX0001` that pass the Step 4 filter  
**And** those records have `OIC_LIFNR` blank or null  
**When** the FM is executed in SE37  
**Then:**
- `ET_VEHICLE_DATA` rows contain blank `OIC_LIFNR`
- No dump, no exception, and no error message is raised on account of the blank field

---

## AC-07 — MOVE-CORRESPONDING Handles Mapping — No Explicit Assignment

**Given** the FM source code is reviewed  
**When** the Step 5 output loop is inspected  
**Then:**
- No explicit assignment `lw_output-oic_lifnr = lw_vehicle_data-oic_lifnr` exists
- `MOVE-CORRESPONDING` is the mechanism carrying `OIC_LIFNR` from `lw_vehicle_data` to `lw_output`
- Field name `OIC_LIFNR` resolves correctly under `MOVE-CORRESPONDING` (confirmed by successful output in AC-05)

---

## AC-08 — No Regression on Existing Output Fields

**Given** valid `IM_DATA-AREA` is provided  
**And** matching records exist that pass the Step 4 filter  
**When** the FM is executed in SE37  
**Then** all previously returned fields are still correctly populated in `ET_VEHICLE_DATA`:

| Field | Verified |
|---|---|
| `AREA` | ☐ |
| `REPORT_NO` | ☐ |
| `TRUCK_NO` | ☐ |
| `TRANSPTRCD` | ☐ |
| `TRANSPLPT` | ☐ |
| `SHNUMBER` | ☐ |
| `STATUS` | ☐ |
| `REJECT_RES` | ☐ |
| `TRUCK_TYPE` | ☐ |
| `TRK_PURPOS` | ☐ |
| `VTWEG` | ☐ |
| `SPART` | ☐ |
| `MATGR` | ☐ |
| `TOTALQTY` | ☐ |
| `FUNCTION` | ☐ |
| `VSTEL` | ☐ |
| `PP_ENTR_DT` | ☐ |
| `PP_ENTR_TM` | ☐ |
| `NAME1` (LFA1 lookup) | ☐ |

---

## AC-09 — Existing Exception Behaviour Unchanged

**Given** the FM is tested with conditions that trigger existing exceptions  
**When** each negative path is executed  
**Then:**

| Scenario | Expected Exception | Verified |
|---|---|---|
| `IM_DATA-AREA` is blank | `INVALID_INPUT` | ☐ |
| No active config in `ZLOG_EXEC_VAR` | `NO_CONFIGURATION_FOUND` | ☐ |
| No records found in `YTTSTX0001` for the area | `NO_VEHICLE` | ☐ |
| Records found but none pass Step 4 filter | Warning message returned, `RETURN` executed, no exception | ☐ |

---

## AC-10 — Transport Completeness

**Given** the change is ready for transport  
**When** the transport request is reviewed  
**Then:**
- `ZSCM_S_VEHICLE_OUTPUT` is included in the transport
- `ZSCM_GET_VEHDATA` (function module / function group) is included in the transport
- `ZSCM_TT_VEHICLE_OUTPUT` is included if the system requires explicit transport of dependent table types
- Both objects are transported together — no split transport that could cause a type mismatch in the target system

---

*End of Document*
