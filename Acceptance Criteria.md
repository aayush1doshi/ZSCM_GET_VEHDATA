# DOI Review: ZSCM_GET_VEHDATA — Performance Improvement via WHERE Clause Enhancement

**Function Module:** `ZSCM_GET_VEHDATA`  
**Table:** `YTTSTX0001`  
**Requirement (DOI):** Add `AREA = im_data-area` AND `FUNCTION IN lr_func` to the `SELECT` WHERE clause, instead of filtering these fields in-memory post-fetch.

---

## 1. What the DOI Is Asking For

The requirement is to push two additional filter conditions into the database `SELECT` WHERE clause on `YTTSTX0001`, rather than fetching a broad result set and then filtering in ABAP memory:

| Filter | Current Approach | Required Approach |
|---|---|---|
| `AREA` | Post-fetch `DELETE WHERE area NE im_data-area` | `WHERE area = im_data-area` in SELECT |
| `FUNCTION` | Post-fetch `DELETE WHERE function NOT IN lr_func[]` | `WHERE function IN lr_func` (or `= lt_config_t-ewm_uom_d`) in SELECT |

This is a pure **database-level performance improvement** — reducing the rows transferred from the DB to the app server.

---

## 2. Current State (What the Code Does Today)

```abap
SELECT area report_no truck_no transptrcd transplpt shnumber status reject_res
       truck_type trk_purpos vtweg spart matgr totalqty function vstel pp_entr_dt pp_entr_tm
  FROM yttstx0001
  INTO TABLE lt_vehicle_data
  FOR ALL ENTRIES IN lt_config_t
  WHERE transplpt  = lt_config_t-transplpt
    AND vstel      = lt_config_t-vstel
    AND trk_purpos = lt_config_t-trk_purpos.

" Post-fetch in-memory filtering:
SORT lt_vehicle_data BY area.
DELETE lt_vehicle_data WHERE area     NE im_data-area.
DELETE lt_vehicle_data WHERE function NOT IN lr_func[].
```

**Problems with the current approach:**
- The SELECT fetches data across **all areas** and **all function values**, then throws away rows in ABAP memory.
- This causes unnecessary network I/O between the DB and app server.
- The in-memory `DELETE` operations are a workaround, not a solution.

---

## 3. What Good Looks Like

### 3.1 Ideal SELECT with Both New WHERE Conditions

The cleanest implementation adds both conditions directly in the `FOR ALL ENTRIES` SELECT:

```abap
" Build lr_func range (already done in current code - reuse it)
CLEAR: lr_func, lr_func[].
LOOP AT lt_config INTO lw_config.
  lr_func-sign   = 'I'.
  lr_func-option = 'EQ'.
  lr_func-low    = lw_config-ewm_uom_d.
  lr_func-high   = ''.
  APPEND lr_func TO lr_func.
  CLEAR lr_func.
ENDLOOP.

lt_config_t[] = lt_config[].
SORT lt_config_t BY transplpt vstel trk_purpos.
DELETE ADJACENT DUPLICATES FROM lt_config_t COMPARING transplpt vstel trk_purpos.

IF lt_config_t[] IS NOT INITIAL.
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
    WHERE transplpt  = lt_config_t-transplpt       " existing
      AND vstel      = lt_config_t-vstel            " existing
      AND trk_purpos = lt_config_t-trk_purpos       " existing
      AND area       = im_data-area                 " NEW per DOI
      AND function   IN lr_func.                    " NEW per DOI
ENDIF.
```

> **Note on `function IN lr_func` vs `function = lt_config_t-ewm_uom_d`:**  
> The DOI mentions `function = LT_CONFIG_T-EWM_UOM_D`. Using `IN lr_func` (a RANGES table) is functionally equivalent and handles multi-value config gracefully. If the config is guaranteed to always yield a single unique `ewm_uom_d`, either form is acceptable. Prefer `IN lr_func` for robustness.

---

### 3.2 Post-Fetch Deletes to Remove

Once the WHERE clause is enhanced, the two in-memory DELETE statements become **redundant and must be removed**:

```abap
" ❌ REMOVE THESE — no longer needed after WHERE clause fix:
SORT lt_vehicle_data BY area.
DELETE lt_vehicle_data WHERE area     NE im_data-area.
DELETE lt_vehicle_data WHERE function NOT IN lr_func[].
```

Leaving them in is not a bug (results remain correct), but it's dead code and misleading.

---

### 3.3 sy-subrc and NO_VEHICLE Handling — Stays the Same

The `sy-subrc <> 0` check and `RAISE no_vehicle` block after the SELECT remains correct as-is. No change needed there.

---

## 4. Index Consideration

The existing code comment references index `YTTSTX0001~ROU`. After adding `AREA` and `FUNCTION` to the WHERE clause, verify with the BASIS/DB team that:

1. The existing index still supports the expanded WHERE clause efficiently.
2. If `AREA` is a high-cardinality field (many distinct values), it is an ideal leading key in a secondary index.
3. If no suitable index exists with `AREA` as a key field, one should be created — otherwise the DB may still do a full table scan despite the WHERE clause improvement.

**Recommended index key order (if new index required):**
```
AREA → TRANSPLPT → VSTEL → TRK_PURPOS → FUNCTION
```

---

## 5. Acceptance Criteria / Definition of Done

| # | Criterion | Check |
|---|---|---|
| 1 | `WHERE area = im_data-area` added to the SELECT on `YTTSTX0001` | ☐ |
| 2 | `WHERE function IN lr_func` (or equivalent) added to the SELECT | ☐ |
| 3 | Post-fetch `DELETE WHERE area NE im_data-area` removed | ☐ |
| 4 | Post-fetch `DELETE WHERE function NOT IN lr_func[]` removed | ☐ |
| 5 | `lr_func` range is still correctly built before the SELECT (no regression) | ☐ |
| 6 | `lt_config_t` de-duplication logic retained | ☐ |
| 7 | `sy-subrc` / `RAISE no_vehicle` logic untouched | ☐ |
| 8 | Downstream Step 4 (truck_type / shnumber / reject_res filter loop) unaffected | ☐ |
| 9 | Index `YTTSTX0001~ROU` confirmed adequate, or new index raised as separate work item | ☐ |
| 10 | Unit test run for at least one valid area + function combination | ☐ |

---

## 6. Risk & Notes

- **`FOR ALL ENTRIES` + RANGES interaction:** SAP does not natively support `IN <ranges_table>` inside a `FOR ALL ENTRIES` WHERE clause in all older kernel versions. If the system is on a kernel that does not support this, the workaround is to loop over `lr_func` and issue separate SELECTs, or convert the RANGES to a subquery. **Verify this on the target system before coding.**
- **Empty `lr_func`:** If `lt_config` yields no rows, `lr_func` will be empty. An `IN` against an empty RANGES is handled safely by ABAP (returns no rows), but add a guard `IF lr_func IS NOT INITIAL` if needed.
- **`area = im_data-area`** is a simple equality condition and is always safe inside `FOR ALL ENTRIES`.

---

*Document prepared for change CD:8085172 / TR:RD2K9A5I5W*
