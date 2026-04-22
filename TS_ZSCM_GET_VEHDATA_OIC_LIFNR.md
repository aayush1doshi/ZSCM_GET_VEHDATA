# Technical Specification

**Subject:** `ZSCM_GET_VEHDATA` — add `OIC_LIFNR` to SELECT and export structure  
**Function Module:** `ZSCM_GET_VEHDATA`  
**Function group:** *(as per system; FM source in `Z_SCM_GET_VEHDATA.txt`)*  
**Version:** 1.0  
**Status:** Draft  
**Related:** DOI `DOI_ZSCM_GET_VEHDATA_OIC_LIFNR.md`, AC `AC_ZSCM_GET_VEHDATA_OIC_LIFNR.md`, FS `FS_ZSCM_GET_VEHDATA_OIC_LIFNR.md`

---

## 1. Objective

Implement the DOI by:

1. Extending dictionary structure `ZSCM_S_VEHICLE_OUTPUT` with `OIC_LIFNR` (same data element as `YTTSTX0001-OIC_LIFNR`).
2. Extending local types `ty_yttstx0001_select` / `ty_yttstx0001_table` in the function group so the SELECT field list and internal tables align.
3. Adding `oic_lifnr` to the named field list of the Step 3 `SELECT` on `YTTSTX0001` (after `pp_entr_tm`).
4. Relying on existing `MOVE-CORRESPONDING` in Step 5 for propagation to `lw_output` — **no** explicit `lw_output-oic_lifnr = lw_vehicle_data-oic_lifnr`.

---

## 2. Interface (unchanged)

| Direction | Name | Type | Notes |
|-----------|------|------|--------|
| Importing | `IM_DATA` | `ZGET_VEHDATA` | Optional in signature; `AREA` validated non-initial. |
| Exporting | `ET_VEHICLE_DATA` | `ZSCM_TT_VEHICLE_OUTPUT` | Line type `ZSCM_S_VEHICLE_OUTPUT` gains `OIC_LIFNR`. |
| Exporting | `LW_MSG` | `ZBAPIRET2` | Unchanged. |
| Exceptions | `INVALID_INPUT`, `NO_CONFIGURATION_FOUND`, `DATABASE_ERROR`, `NO_VEHICLE` | — | Unchanged. |

---

## 3. Dictionary objects

| Object | Change |
|--------|--------|
| `YTTSTX0001` | Verify `OIC_LIFNR` exists; no structural change in scope. |
| `ZSCM_S_VEHICLE_OUTPUT` | Add component `OIC_LIFNR` with **identical** data element (and domain, if applicable) as `YTTSTX0001-OIC_LIFNR`. Activate **before** function group/FM. |
| `ZSCM_TT_VEHICLE_OUTPUT` | Table type of `ZSCM_S_VEHICLE_OUTPUT`; no direct edit required if line type picks up new field automatically. Confirm activation in target after structure change. |

---

## 4. Function group local types

| Type | Change |
|------|--------|
| `ty_yttstx0001_select` | Add `OIC_LIFNR` in the **same order** as the SELECT list (after `PP_ENTR_TM`). Must match SELECT column order per existing comment in source. |
| `ty_yttstx0001_table` | `TABLE OF ty_yttstx0001_select` — no separate field list if defined that way. |

If these types are copied from or include a global type, extend the ultimate source type consistently.

---

## 5. Algorithm by step (current code baseline)

Reference: extracted FM `Z_SCM_GET_VEHDATA.txt`.

### Step 1 — Input validation

- Lines 84–89: `IM_DATA-AREA` initial → message, `INVALID_INPUT`. **No change.**

### Step 2 — Configuration

- Lines 94–144: `ZLOG_EXEC_VAR` by `name = 'ZSCM_GET_VEHDATA'` and `active = 'X'`; completeness checks. **No change.**

### Step 3 — `YTTSTX0001` SELECT

- Lines 166–192: `FOR ALL ENTRIES IN lt_config_t` with conditions on `area`, `transplpt`, `vstel`, `function`, `trk_purpos`. **WHERE clause and FAE pattern unchanged.**

**Required modification:** Append to the named list (after `pp_entr_tm`):

```abap
               pp_entr_tm
               oic_lifnr
```

- Do **not** use `SELECT *`.
- Do not reorder or remove existing fields.

### Step 4 — In-memory filter and `LFA1`

- Lines 226–268: Filter `truck_type = lw_config-remarks`, `shnumber` and `reject_res` space; build `ltr_lifnr` from `transptrcd`; `SELECT` from `LFA1`. **No change** to filter logic or vendor lookup keys.

### Step 5 — Output loop

- Lines 275–295: `LOOP AT lt_vehicle_filter`, `MOVE-CORRESPONDING lw_vehicle_data TO lw_output`, explicit `PP_ENTR_DT` / `PP_ENTR_TM`, `NAME1` from `lt_lfa1` by `transptrcd`. **No new explicit assignment for `OIC_LIFNR`** once both work areas contain the field with matching names.

### Step 6 — Success

- Lines 300–302: Line count. **No change** except output table rows now include `OIC_LIFNR`.

---

## 6. Error handling and messages

- All `TRY/CATCH` around configuration and vehicle DB access remain as implemented.
- No new exceptions for `OIC_LIFNR`.
- Message IDs and scenarios in AC-09 remain the contract.

---

## 7. Performance and database

- One additional column in an existing named `SELECT`; no extra round trips or joins.
- No index change required solely for this field unless platform-specific analysis dictates otherwise (out of scope unless measured).

---

## 8. Activation and transport order

1. Activate `ZSCM_S_VEHICLE_OUTPUT`.
2. Activate function group includes (local types) if maintained separately.
3. Activate `ZSCM_GET_VEHDATA` / function group.
4. Single transport request containing dependent objects; include `ZSCM_TT_VEHICLE_OUTPUT` if the system requires explicit transport of table types (per AC-10).

---

## 9. Verification matrix (technical ↔ AC)

| AC | Technical check |
|----|------------------|
| AC-01 | SE11: `ZSCM_S_VEHICLE_OUTPUT` has `OIC_LIFNR`; data element matches `YTTSTX0001`. |
| AC-02 | SE11: `ZSCM_TT_VEHICLE_OUTPUT` shows inherited field; active. |
| AC-03 | Function group include: `ty_yttstx0001_select` extended; syntax check. |
| AC-04 | Source: `oic_lifnr` in SELECT list; not `SELECT *`; WHERE unchanged. |
| AC-05 | SE37: populated `OIC_LIFNR` in DB → same value in `ET_VEHICLE_DATA`. |
| AC-06 | Blank `OIC_LIFNR` in DB → blank in export; no dump. |
| AC-07 | No explicit `lw_output-oic_lifnr = ...`; `MOVE-CORRESPONDING` only. |
| AC-08 | Regression checklist on listed fields including `NAME1`. |
| AC-09 | Negative tests per AC table. |
| AC-10 | Transport object list complete. |

---

## 10. Appendix — current SELECT excerpt (before change)

From `Z_SCM_GET_VEHDATA.txt` (Step 3):

```167:185:c:\AI Development\9. Z_SCM_GET_VEHDATA - Veh Destination\Z_SCM_GET_VEHDATA.txt
        SELECT area
               report_no
               truck_no
               transptrcd
               transplpt
               shnumber
               status
               reject_res
               truck_type
               trk_purpos
               vtweg
               spart
               matgr
               totalqty
               function
               vstel
               pp_entr_dt
               pp_entr_tm
          FROM yttstx0001
```

**After change:** add `oic_lifnr` immediately after `pp_entr_tm` (and extend `ty_yttstx0001_select` / `ZSCM_S_VEHICLE_OUTPUT` as above).

---

*End of Technical Specification*
