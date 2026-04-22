# Document of Intent (DOI)

**Function Module:** `ZSCM_GET_VEHDATA`  
**Change Description:** Add field `OIC_LIFNR` to vehicle data fetch and output  
**Document Status:** Draft  
**Prepared By:** *(Author)*  
**Date:** *(Date)*

---

## 1. Background

The function module `ZSCM_GET_VEHDATA` retrieves vehicle data from the custom table `YTTSTX0001` based on configuration parameters fetched from `ZLOG_EXEC_VAR`. The filtered records are returned via the export table `ET_VEHICLE_DATA` of type `ZSCM_TT_VEHICLE_OUTPUT`.

Currently, the SELECT query on `YTTSTX0001` does not include the field `OIC_LIFNR`, and accordingly, this field is not present in the FM's output structure or export table.

---

## 2. Objective

Extend the function module `ZSCM_GET_VEHDATA` to:

1. Fetch the field `OIC_LIFNR` from `YTTSTX0001` as part of the existing SELECT query into internal table `lt_vehicle_data`.
2. Include `OIC_LIFNR` in the FM output by adding it to the output structure `ZSCM_S_VEHICLE_OUTPUT` and propagating it through to the export table `ET_VEHICLE_DATA` (type `ZSCM_TT_VEHICLE_OUTPUT`).

---

## 3. Scope of Changes

### 3.1 Database Objects

| Object | Type | Change |
|---|---|---|
| `YTTSTX0001` | Transparent Table | No structural change — `OIC_LIFNR` already exists in the table |
| `ZSCM_S_VEHICLE_OUTPUT` | Dictionary Structure | Add field `OIC_LIFNR` (type aligned with `YTTSTX0001-OIC_LIFNR`) |
| `ZSCM_TT_VEHICLE_OUTPUT` | Table Type | No change required — it is a table type of `ZSCM_S_VEHICLE_OUTPUT`; picks up the new field automatically after structure change |

> **Note:** The data type and domain for `OIC_LIFNR` in `ZSCM_S_VEHICLE_OUTPUT` must be consistent with the corresponding field definition in `YTTSTX0001`. Confirm the data element/domain before activation.

### 3.2 Function Module — `ZSCM_GET_VEHDATA`

#### 3.2.1 Step 3: SELECT Query on `YTTSTX0001`

**Current SELECT field list (relevant excerpt):**

```abap
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
  INTO TABLE lt_vehicle_data
  FOR ALL ENTRIES IN lt_config_t
  WHERE ...
```

**Required Change:**

Add `oic_lifnr` to the SELECT field list, after `pp_entr_tm`:

```abap
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
       oic_lifnr          " <<< ADDED
  FROM yttstx0001
  INTO TABLE lt_vehicle_data
  FOR ALL ENTRIES IN lt_config_t
  WHERE ...
```

> **Prerequisite:** The internal table type `ty_yttstx0001_select` (used as the work area `lw_vehicle_data`) and the internal table type `ty_yttstx0001_table` (used as `lt_vehicle_data` and `lt_vehicle_filter`) must also include `OIC_LIFNR`. These types are likely defined globally or in the function group's include — they must be extended accordingly.

#### 3.2.2 Step 5: Output Population

The existing output loop uses `MOVE-CORRESPONDING` from `lw_vehicle_data` to `lw_output`:

```abap
LOOP AT lt_vehicle_filter INTO lw_vehicle_data.
  MOVE-CORRESPONDING lw_vehicle_data TO lw_output.
  ...
  APPEND lw_output TO et_vehicle_data.
  CLEAR lw_output.
ENDLOOP.
```

Since `MOVE-CORRESPONDING` is used, no additional explicit field assignment is required for `OIC_LIFNR` — it will be moved automatically once:

- `OIC_LIFNR` is present in `lw_vehicle_data` (via the updated SELECT and internal table type), and
- `OIC_LIFNR` is present in `lw_output` (via the updated output structure `ZSCM_S_VEHICLE_OUTPUT`).

No code change is needed in Step 5 beyond ensuring the structure changes are in place.

---

## 4. Objects to Be Changed

| # | Object Name | Object Type | Change |
|---|---|---|---|
| 1 | `YTTSTX0001` | Database Table | Verify `OIC_LIFNR` field exists (no change expected) |
| 2 | `ZSCM_S_VEHICLE_OUTPUT` | ABAP Dictionary Structure | Add field `OIC_LIFNR` |
| 3 | `ty_yttstx0001_select` | Local Type (Function Group) | Add `OIC_LIFNR` field |
| 4 | `ty_yttstx0001_table` | Local Type (Function Group) | Implicitly covered if based on `ty_yttstx0001_select` |
| 5 | `ZSCM_GET_VEHDATA` | Function Module | Add `oic_lifnr` to SELECT field list in Step 3 |

---

## 5. Objects Not in Scope

- No change to the WHERE clause of the `YTTSTX0001` SELECT query.
- No change to in-memory filter logic in Step 4 (truck type, shnumber, reject_res conditions).
- No change to the `LFA1` vendor name lookup logic.
- No change to FM exceptions, input parameters, or configuration fetch logic.
- `ZSCM_TT_VEHICLE_OUTPUT` (table type) requires no direct change — it inherits `OIC_LIFNR` from the updated line type `ZSCM_S_VEHICLE_OUTPUT`.

---

## 6. Assumptions and Dependencies

1. `OIC_LIFNR` exists as a field in `YTTSTX0001` in the target system. This must be confirmed before development begins.
2. A suitable data element exists in the ABAP Dictionary for `OIC_LIFNR` (e.g., `LIFNR` or a custom data element). The developer must use the same data element as defined in `YTTSTX0001` when adding the field to `ZSCM_S_VEHICLE_OUTPUT`.
3. The calling program(s) or RFC consumer consuming `ET_VEHICLE_DATA` may need to be updated to display or process `OIC_LIFNR` — this is outside the scope of this DOI but must be assessed by the relevant team.
4. The local types `ty_yttstx0001_select` and `ty_yttstx0001_table` are defined within the function group. If they are generated or derived from a global type, that global type must also be extended.

---

## 7. Testing Considerations

| # | Test Scenario | Expected Result |
|---|---|---|
| 1 | Execute FM with valid `IM_DATA-AREA` where `YTTSTX0001` records have `OIC_LIFNR` populated | `ET_VEHICLE_DATA` rows contain correct `OIC_LIFNR` values |
| 2 | Execute FM with valid `IM_DATA-AREA` where `YTTSTX0001` records have `OIC_LIFNR` blank/null | `ET_VEHICLE_DATA` rows contain blank `OIC_LIFNR` — no dump, no error |
| 3 | Execute FM where no records pass the Step 4 in-memory filter | FM returns warning message as before; `OIC_LIFNR` behaviour is not relevant |
| 4 | Execute FM with invalid `IM_DATA-AREA` (existing negative test) | Exception `INVALID_INPUT` raised — behaviour unchanged |
| 5 | Regression: All previously fetched fields (`TRANSPTRCD`, `PP_ENTR_DT`, `PP_ENTR_TM`, `NAME1`, etc.) still populate correctly | No regression in existing output fields |

---

## 8. Transport and Activation Sequence

1. Activate `ZSCM_S_VEHICLE_OUTPUT` (Dictionary structure) — this must be activated **before** the function module to avoid type mismatch errors.
2. Activate local type changes in the function group include (if applicable).
3. Activate and test `ZSCM_GET_VEHDATA`.
4. Include all objects in the same transport request.

---

*End of Document*
