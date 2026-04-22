# Implementation Plan — `ZSCM_GET_VEHDATA` / `OIC_LIFNR`

**Change:** Expose `YTTSTX0001-OIC_LIFNR` via `ET_VEHICLE_DATA`  
**References:** DOI, AC, `FS_ZSCM_GET_VEHDATA_OIC_LIFNR.md`, `TS_ZSCM_GET_VEHDATA_OIC_LIFNR.md`  
**Status:** Draft

---

## 1. Preconditions (before development)

| # | Task | Owner | Done criteria |
|---|------|--------|----------------|
| 1.1 | Confirm `OIC_LIFNR` exists on `YTTSTX0001` in DEV (SE11) | Functional / Dev | Field visible; note data element |
| 1.2 | Confirm `ZSCM_S_VEHICLE_OUTPUT` current field list and usage (where used) | Dev | Impact list for recompilation |
| 1.3 | Open transport request for all objects in one package | Basis / Dev | TR number recorded |
| 1.4 | Baseline test: run `ZSCM_GET_VEHDATA` in SE37 for a known `IM_DATA-AREA`; capture `ET_VEHICLE_DATA` row sample | QA / Dev | Saved variant or screenshot for regression |

---

## 2. Development sequence (order matters)

Execute in this order to avoid type mismatches and activation errors.

### Phase A — Dictionary

| Step | Action | Validates |
|------|--------|-----------|
| A.1 | In SE11, add `OIC_LIFNR` to `ZSCM_S_VEHICLE_OUTPUT` using the **same data element** as `YTTSTX0001-OIC_LIFNR` | AC-01 |
| A.2 | Activate `ZSCM_S_VEHICLE_OUTPUT`; fix any dependent short dumps in inactive dependents if prompted | AC-01 |
| A.3 | Open `ZSCM_TT_VEHICLE_OUTPUT` in SE11; confirm line type shows new field (no structural edit if table type is “table of” structure) | AC-02 |
| A.4 | Activate `ZSCM_TT_VEHICLE_OUTPUT` if required by system | AC-02 |

### Phase B — Function group types

| Step | Action | Validates |
|------|--------|-----------|
| B.1 | Locate include defining `ty_yttstx0001_select` / `ty_yttstx0001_table` | AC-03 |
| B.2 | Add `OIC_LIFNR` to `ty_yttstx0001_select` in **same position** as SELECT columns (after `PP_ENTR_TM`) | AC-03, AC-04 |
| B.3 | Ensure `ty_yttstx0001_table` remains `TABLE OF ty_yttstx0001_select` (or equivalent single source of truth) | AC-03 |
| B.4 | Syntax check function group (SE80) | AC-03 |

### Phase C — Function module source

| Step | Action | Validates |
|------|--------|-----------|
| C.1 | In Step 3 `SELECT` on `YTTSTX0001`, add `oic_lifnr` to the **named** list immediately after `pp_entr_tm`; do **not** use `SELECT *` | AC-04 |
| C.2 | Do **not** change WHERE, `FOR ALL ENTRIES`, or existing selected fields | AC-04 |
| C.3 | In Step 5, **do not** add `lw_output-oic_lifnr = lw_vehicle_data-oic_lifnr`; keep `MOVE-CORRESPONDING` as sole mapping for this field | AC-07 |
| C.4 | Activate function module / function group | AC-04 |

---

## 3. Unit / technical verification (developer)

| # | Check | Expected |
|---|--------|----------|
| 3.1 | SE11 structure vs table field | Data element match `YTTSTX0001` ↔ `ZSCM_S_VEHICLE_OUTPUT` |
| 3.2 | Code review | No `SELECT *`; no explicit `oic_lifnr` assign in Step 5 |
| 3.3 | SE37 happy path | `OIC_LIFNR` populated matches DB (AC-05) |
| 3.4 | SE37 blank source | Export `OIC_LIFNR` initial; no dump (AC-06) |
| 3.5 | Regression | All fields in AC-08 table + `NAME1` still correct (AC-08) |
| 3.6 | Exceptions | Blank area, no config, no vehicles, all filtered out — per AC-09 (AC-09) |

---

## 4. QA / formal acceptance

- Walk through **AC-01–AC-10** in `AC_ZSCM_GET_VEHDATA_OIC_LIFNR.md`; mark verified.
- Attach evidence: SE37 test logs, SE11 screenshots if required by process.

---

## 5. Transport and promotion

| Step | Action | Note |
|------|--------|------|
| 5.1 | Ensure TR contains `ZSCM_S_VEHICLE_OUTPUT`, function group / `ZSCM_GET_VEHDATA`, and `ZSCM_TT_VEHICLE_OUTPUT` if your landscape requires explicit table type transport | AC-10 |
| 5.2 | Move **one** coherent TR (avoid split: structure active in QAS without FM, or reverse) | AC-10 |
| 5.3 | After import to QAS/PRD: spot-check SE11 + one SE37 execution | |

---

## 6. Post-go-live (out of DOI scope but recommended)

| Task | Owner |
|------|--------|
| Identify RFC/report programs consuming `ET_VEHICLE_DATA` | Functional |
| Update UI/interfaces if `OIC_LIFNR` must be shown or validated | App teams |

---

## 7. Rollback

| Scenario | Action |
|----------|--------|
| Structure/FM out of sync in target | Restore previous TR or revert objects in reverse order: FM first if reverting code only; if reverting structure, coordinate with all consumers — prefer **forward fix** (complete TR) over partial rollback |
| Defect found after transport | New correction TR: fix forward; avoid removing `OIC_LIFNR` from structure if callers already compiled against it without coordination |

---

## 8. Effort and risk (indicative)

| Area | Effort | Risk |
|------|--------|------|
| Dictionary + types + SELECT | Low | Low if activation order followed |
| Regression / exception tests | Low–Medium | Medium if many consumers recompile |
| Downstream UI changes | Variable | Out of scope for core change |

---

## 9. Checklist summary

- [ ] Preconditions (1.1–1.4)  
- [ ] Phase A: structure + table type  
- [ ] Phase B: local types  
- [ ] Phase C: FM SELECT + no explicit Step 5 assign  
- [ ] Developer tests (Section 3)  
- [ ] AC sign-off (Section 4)  
- [ ] Single TR promotion (Section 5)  

---

*End of Implementation Plan*
