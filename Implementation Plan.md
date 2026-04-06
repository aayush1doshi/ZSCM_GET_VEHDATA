# Implementation Plan: ZSCM_GET_VEHDATA — YTTSTX0001 SQL Performance

| Field | Value |
|-------|--------|
| **Function module** | `ZSCM_GET_VEHDATA` |
| **Table** | `YTTSTX0001` |
| **Change / TR** | CD:8085172 / TR:RD2K9A5I5W |
| **Workspace copy** | `ZSCM_GET_VEHDATA.txt` (mirror of SE37 source) |
| **Requirements** | `DOI.txt`, `Acceptance Criteria.md` |

---

## 1. Executive summary

**Problem:** Step 3 reads `YTTSTX0001` with `FOR ALL ENTRIES` on `transplpt`, `vstel`, `trk_purpos` only, then discards rows in ABAP using `DELETE` on `area` and `function`.

**Solution:** Add `area = im_data-area` and `function IN lr_func` to the same `SELECT` `WHERE` clause, then remove the redundant `SORT`/`DELETE` block.

**Outcome:** Fewer rows transferred from DB to app server; behavior for callers and Step 4 onward stays the same if predicates match previous in-memory filters.

**Out of scope:** Refactors outside Step 3; new index creation (track as separate BASIS task if needed).

---

## 2. Preconditions (before coding)

| # | Task | Owner | Notes |
|---|------|-------|--------|
| P1 | Read `DOI.txt` and `Acceptance Criteria.md` | Dev | Align on `area` + `function` in SQL |
| P2 | Confirm ABAP release/kernel allows `FOR ALL ENTRIES` + `IN lr_func` in one `SELECT` | Dev / BASIS | If not, use fallback (see §7) |
| P3 | Verify `ty_config_param` / `ZLOG_EXEC_VAR` field for UOM/function (`ewb_uom_d` vs `ewm_uom_d` in source) | Dev | `lr_func` must use the correct DDIC field |
| P4 | Transport branch / task ready for FM change | Basis | Same TR as referenced in code comments |

---

## 3. Work breakdown — implementation order

### 3.1 Step A — Edit Step 3 `SELECT` (`ZSCM_GET_VEHDATA`, Step 3)

**Location (workspace):** `ZSCM_GET_VEHDATA.txt` approx. lines 164–188.

**Keep unchanged above the `SELECT`:**

- `CLEAR lr_func` + loop on `lt_config` building `lr_func` from the config function field (lines 150–156).
- `lt_config_t[] = lt_config[]`, `SORT`, `DELETE ADJACENT DUPLICATES` (lines 158–160).
- `IF NOT lt_config_t[] IS INITIAL.` (line 164).

**Replace the `WHERE` clause** so it includes the three existing join columns **plus** the two new predicates:

```abap
WHERE transplpt  = lt_config_t-transplpt
  AND vstel      = lt_config_t-vstel
  AND trk_purpos = lt_config_t-trk_purpos
  AND area       = im_data-area
  AND function   IN lr_func.
```

**Also:**

- Remove stray comment fragments after `AND` on old lines (e.g. `" lw_config-transplpt"`).
- Update the comment “5 WHERE conditions” → **five** predicates total: `transplpt`, `vstel`, `trk_purpos`, `area`, `function` (or state “5 AND conditions” clearly).
- Remove the decorative `********************************` line if your standards allow (optional cleanup).

### 3.2 Step B — Remove post-`SELECT` in-memory filter (ELSE branch)

**Location:** lines 199–204 (inside `IF sy-subrc <> 0` … `ELSE`).

**Remove entirely:**

- `ELSE.`
- `SORT lt_vehicle_data BY area.`
- `DELETE lt_vehicle_data WHERE area NE im_data-area.`
- `DELETE lt_vehicle_data WHERE function NOT IN lr_func[].`
- `ENDIF.` that closes only this `ELSE` **if** it becomes empty.

**Required restructuring:** After the `SELECT`, you only need **one** `IF sy-subrc <> 0` block for `RAISE no_vehicle`. Typical pattern:

```abap
IF sy-subrc <> 0.
  " CONCATENATE message + RAISE no_vehicle
ENDIF.
```

Do **not** leave an empty `ELSE`; merge so success path falls through with no redundant `ELSE`.

### 3.3 Step C — Optional guard for empty `lr_func`

If `lt_config_t` is initial, the `SELECT` is already skipped. If `lt_config_t` is not initial but `lr_func` could be empty (data error), decide:

- **Option 1:** `IF lr_func IS NOT INITIAL.` around the `SELECT` (and handle “no function” with same `NO_VEHICLE` or explicit message — product decision).
- **Option 2:** Rely on standard empty-range behavior; document in technical notes.

`Acceptance Criteria.md` flags this; pick one approach and document in transport notes.

### 3.4 Step D — SAP system steps (mirror of file edit)

1. SE37 → `ZSCM_GET_VEHDATA` → change mode.
2. Apply Steps A–C to the active source.
3. Syntax check (Ctrl+F2).
4. Activate function module.
5. Update `ZSCM_GET_VEHDATA.txt` in this workspace if you maintain a Git/offline copy.

---

## 4. What must not change

| Area | Requirement |
|------|-------------|
| Step 1 | `im_data-area` mandatory → `INVALID_INPUT` unchanged |
| Step 2 | `ZLOG_EXEC_VAR` read and validation unchanged |
| Step 3 | `sy-subrc <> 0` → message 006 + `RAISE no_vehicle` unchanged in intent |
| Step 4 | Loop on `truck_type`, `shnumber`, `reject_res`; `ltr_lifnr` / LFA1 unchanged |
| Step 5–6 | Output mapping and success message unchanged |

---

## 5. Testing plan

| # | Scenario | Expected |
|---|----------|----------|
| T1 | Valid area + DB rows matching config `function` + Step 4 rules | Same qualitative result as before change |
| T2 | Valid area + no DB rows | `NO_VEHICLE`, message 006 |
| T3 | No active config | `NO_CONFIGURATION_FOUND` |
| T4 | Incomplete config | `NO_CONFIGURATION_FOUND` |
| T5 | DB returns rows but Step 4 filters all | Warning, message 010, `RETURN` |
| T6 | (Optional) ST05 before/after row counts / response time | Improvement or at least no regression |

Minimum for sign-off: **T1** and one regression (**T2** or **T3**).

---

## 6. Index and performance (parallel track)

| # | Action | Owner |
|---|--------|--------|
| I1 | Review execution plan / ST05 for `YTTSTX0001` with new `WHERE` | BASIS / Dev |
| I2 | If full table scan: open work item for index (e.g. leading `AREA`, then `TRANSPLPT`, `VSTEL`, `TRK_PURPOS`, `FUNCTION`) | BASIS |

Do not block code merge on I2 unless project gates require it; document follow-up.

---

## 7. Risk: `FOR ALL ENTRIES` + `IN lr_func`

If syntax check or runtime fails on your release:

1. **Fallback A:** Loop at `lr_func`, single-value `function = lr_func-low` inside a loop collecting into `lt_vehicle_data` (with `APPEND LINES` and `SORT`/`DELETE DUPLICATES` if duplicates possible).
2. **Fallback B:** Split by `area` already fixed (`im_data-area`); multiple `SELECT`s by function value — same as A in practice.

Record the chosen fallback in this file or transport documentation.

---

## 8. Rollback

- Restore previous FM version from version history or pre-change transport.
- No DDIC change required for this DOI if only ABAP is touched.

---

## 9. Definition of done

| # | Criterion | Done |
|---|-----------|------|
| 1 | `WHERE area = im_data-area` on `YTTSTX0001` `SELECT` | ☐ |
| 2 | `WHERE function IN lr_func` (or approved equivalent) on same `SELECT` | ☐ |
| 3 | Post-fetch `DELETE WHERE area NE im_data-area` removed | ☐ |
| 4 | Post-fetch `DELETE WHERE function NOT IN lr_func[]` removed | ☐ |
| 5 | `lr_func` built before `SELECT` without regression | ☐ |
| 6 | `lt_config_t` de-duplication retained | ☐ |
| 7 | `sy-subrc` / `RAISE no_vehicle` unchanged in behavior | ☐ |
| 8 | Step 4 downstream logic unaffected | ☐ |
| 9 | Index adequate or follow-up logged | ☐ |
| 10 | At least one positive test (valid area + function) executed | ☐ |

---

## 10. Sign-off (fill in)

| Role | Name | Date |
|------|------|------|
| Developer | | |
| Technical review | | |
| Functional / SME | | |

---

*Built from `DOI.txt`, `Acceptance Criteria.md`, and `ZSCM_GET_VEHDATA.txt`.*
