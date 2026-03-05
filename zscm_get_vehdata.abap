FUNCTION zscm_get_vehdata.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IM_DATA) TYPE  ZGET_VEHDATA OPTIONAL
*"  EXPORTING
*"     VALUE(ET_VEHICLE_DATA) TYPE  ZSCM_TT_VEHICLE_OUTPUT
*"     VALUE(LW_MSG) TYPE  ZBAPIRET2
*"  EXCEPTIONS
*"      INVALID_INPUT
*"      NO_CONFIGURATION_FOUND
*"      DATABASE_ERROR
*"      NO_VEHICLE
*"----------------------------------------------------------------------

*----------------------------------------------------------------------*
* Data Declarations
*----------------------------------------------------------------------*
  DATA: lt_config         TYPE ty_config_table,
        lw_config         TYPE ty_config_param,
        lt_vehicle_data   TYPE ty_yttstx0001_table,
        lw_vehicle_data   TYPE ty_yttstx0001_select,
        lw_output         TYPE zscm_s_vehicle_output,
        lv_line           TYPE i,
        lv_count_filtered TYPE i,
        lv_count_selected TYPE i,
        lv_msg_text       TYPE string.

  DATA lo_exception TYPE REF TO cx_root.

*----------------------------------------------------------------------*
* Constants
*----------------------------------------------------------------------*
  CONSTANTS: lc_fm_name TYPE rvari_vnam VALUE 'ZSCM_GET_VEHDATA',
             lc_active  TYPE zactive_flag VALUE 'X',
             lc_space   TYPE char1 VALUE ' ',
             lc_msg_s   TYPE char1 VALUE 'S',
             lc_msg_e   TYPE char1 VALUE 'E',
             lc_msg_w   TYPE char1 VALUE 'W'.

  CLEAR: et_vehicle_data,
         lw_msg.

*----------------------------------------------------------------------*
* Step 1: Input validation
*----------------------------------------------------------------------*
  IF im_data-area IS INITIAL.
    lw_msg-type = lc_msg_e.
    lw_msg-id = 'ZLOG'.
    lw_msg-message = 'Input parameter IM_DATA-AREA is mandatory'(001).
    RAISE invalid_input.
  ENDIF.

*----------------------------------------------------------------------*
* Step 2: Fetch configuration parameters
*----------------------------------------------------------------------*
  TRY.
      SELECT name
             active
             remarks
             trk_purpos
             ewb_uom_d
             vstel
             transplpt
        FROM zlog_exec_var
        INTO TABLE lt_config
        WHERE name = lc_fm_name
          AND active = lc_active.

      IF sy-subrc <> 0.
        lw_msg-type = lc_msg_e.
        lw_msg-id = 'ZLOG'.
        lw_msg-message = 'No active configuration found for function module'(002).
        RAISE no_configuration_found.
      ENDIF.

    CATCH cx_root INTO lo_exception.
      lv_msg_text = lo_exception->get_text( ).
      CONCATENATE 'Database error while fetching configuration:'(003)
                  lv_msg_text
             INTO lw_msg-message SEPARATED BY space.
      lw_msg-type = lc_msg_e.
      lw_msg-id = 'ZLOG'.
      RAISE database_error.
  ENDTRY.

*----------------------------------------------------------------------*
* Step 3/4: Process all configuration records
*----------------------------------------------------------------------*
  LOOP AT lt_config INTO lw_config.
    IF lw_config-ewb_uom_d IS INITIAL OR
       lw_config-trk_purpos IS INITIAL OR
       lw_config-remarks IS INITIAL OR
       lw_config-vstel IS INITIAL OR
       lw_config-transplpt IS INITIAL.
      lw_msg-type = lc_msg_e.
      lw_msg-id = 'ZLOG'.
      lw_msg-message = 'Configuration data is incomplete. Check ZLOG_EXEC_VAR'(005).
      RAISE no_configuration_found.
    ENDIF.

    CLEAR lt_vehicle_data.

    TRY.
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
          FROM yttstx0001
          INTO TABLE lt_vehicle_data
          WHERE area       = im_data-area
            AND transplpt  = lw_config-transplpt
            AND vstel      = lw_config-vstel
            AND function   = lw_config-ewb_uom_d
            AND trk_purpos = lw_config-trk_purpos.

      CATCH cx_root INTO lo_exception.
        lv_msg_text = lo_exception->get_text( ).
        CONCATENATE 'Database error while fetching vehicle data:'(007)
                    lv_msg_text
               INTO lw_msg-message SEPARATED BY space.
        lw_msg-type = lc_msg_e.
        lw_msg-id = 'ZLOG'.
        RAISE database_error.
    ENDTRY.

    LOOP AT lt_vehicle_data INTO lw_vehicle_data.
      IF lw_vehicle_data-truck_type = lw_config-remarks AND
         lw_vehicle_data-shnumber   = lc_space AND
         lw_vehicle_data-reject_res = lc_space.
        MOVE-CORRESPONDING lw_vehicle_data TO lw_output.
        APPEND lw_output TO et_vehicle_data.
        CLEAR lw_output.
      ENDIF.
    ENDLOOP.
  ENDLOOP.

  DESCRIBE TABLE et_vehicle_data LINES lv_count_filtered.
  IF lv_count_filtered = 0.
    CONCATENATE 'No vehicle data found for configured criteria in area'(010)
                im_data-area
           INTO lw_msg-message SEPARATED BY space.
    lw_msg-type = lc_msg_w.
    lw_msg-id = 'ZLOG'.
    RAISE no_vehicle.
  ENDIF.

*----------------------------------------------------------------------*
* Step 5: Success message
*----------------------------------------------------------------------*
  SORT et_vehicle_data BY area report_no truck_no transptrcd transplpt shnumber
                          status reject_res truck_type trk_purpos vtweg spart
                          matgr totalqty function vstel.
  DELETE ADJACENT DUPLICATES FROM et_vehicle_data COMPARING ALL FIELDS.

  DESCRIBE TABLE et_vehicle_data LINES lv_line.
  lv_count_selected = lv_line.
  CONCATENATE 'Vehicle data fetched successfully. Records:'(011)
              lv_count_selected
         INTO lw_msg-message SEPARATED BY space.
  lw_msg-type = lc_msg_s.
  lw_msg-id = 'ZLOG'.

ENDFUNCTION.
