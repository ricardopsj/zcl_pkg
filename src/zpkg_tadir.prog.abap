*&---------------------------------------------------------------------*
*& Report ZPKG_TADIR
*&---------------------------------------------------------------------*
*& Lista el catálogo de objetos (TADIR) con ZCL_ALV y permite cambiar
*& de paquete los objetos seleccionados (botón "Cambiar paquete").
*&---------------------------------------------------------------------*
report zpkg_tadir.

tables: tadir.

types: begin of tys_out.
    include type tadir.
types: status  type icon_d,
       message type bapi_msg,
       end of tys_out.
types: tyt_out type standard table of tys_out with default key.

*----------------------------------------------------------------------*
* ALV
*----------------------------------------------------------------------*
class lcl_alv definition inheriting from zcl_alv.
  public section.
    methods display_pf_status redefinition.
    methods create_fieldcat_exit redefinition.
    "Botón CHG_PKG: ZCL_ALV llama a OK_<código de función>
    methods ok_chg_pkg importing it_rows type zalv_t_row.

  private section.
    methods ask_devclass
      returning value(rv_devclass) type devclass.
    methods confirm
      importing iv_lines     type i
                iv_devclass  type devclass
      returning value(rv_ok) type abap_bool.
    methods has_auth
      importing iv_devclass  type devclass
                is_out       type tys_out
      returning value(rv_ok) type abap_bool.
    methods move_object
      importing iv_devclass type devclass
      changing  cs_out      type tys_out.
endclass.

class lcl_alv implementation.

  method display_pf_status.
    set pf-status 'ZSTATUS' of program sy-repid.
  endmethod.

  method create_fieldcat_exit.
    case ref_fieldcat->fieldname.
      when 'STATUS'.
        ref_fieldcat->icon    = abap_true.
        ref_fieldcat->coltext = 'Estado'.
        ref_fieldcat->reptext = 'Estado'.
      when 'MESSAGE'.
        ref_fieldcat->coltext   = 'Resultado'.
        ref_fieldcat->reptext   = 'Resultado'.
        ref_fieldcat->col_opt   = abap_false.
        ref_fieldcat->outputlen = 60.
    endcase.
  endmethod.

  method ok_chg_pkg.
    data: lv_ok  type i,
          lv_nc  type i,
          lv_err type i.
    field-symbols: <lt_out> type tyt_out.

    if it_rows is initial.
      message 'Seleccione al menos un objeto' type 'S' display like 'E'.
      return.
    endif.

    data(lv_devclass) = ask_devclass( ).
    if lv_devclass is initial.
      return.
    endif.

    if confirm( iv_lines = lines( it_rows ) iv_devclass = lv_devclass ) eq abap_false.
      return.
    endif.

    assign ref_data->* to <lt_out>.
    loop at it_rows assigning field-symbol(<ls_row>).
      read table <lt_out> index <ls_row>-index assigning field-symbol(<ls_out>).
      if sy-subrc ne 0.
        continue.
      endif.
      move_object( exporting iv_devclass = lv_devclass
                   changing  cs_out      = <ls_out> ).
      case <ls_out>-status.
        when icon_led_green.
          add 1 to lv_ok.
        when icon_led_yellow.
          add 1 to lv_nc.
        when others.
          add 1 to lv_err.
      endcase.
    endloop.
    commit work.

    refresh_display( ).
    message |Movidos a { lv_devclass }: { lv_ok }. Sin cambio: { lv_nc }. Con error: { lv_err }.| type 'S'.
  endmethod.

  method ask_devclass.
    data: lt_fields     type standard table of sval,
          lv_returncode type c length 1.

    lt_fields = value #( ( tabname = 'TDEVC' fieldname = 'DEVCLASS' field_obl = abap_true ) ).
    call function 'POPUP_GET_VALUES'
      exporting
        popup_title     = 'Cambiar a paquete'
      importing
        returncode      = lv_returncode
      tables
        fields          = lt_fields
      exceptions
        error_in_fields = 1
        others          = 2.
    if sy-subrc ne 0 or lv_returncode eq 'A' or lt_fields is initial.
      return.
    endif.

    rv_devclass = to_upper( condense( lt_fields[ 1 ]-value ) ).

    select single @abap_true
      from tdevc
     where devclass eq @rv_devclass
      into @data(lv_exists).
    if sy-subrc ne 0 or lv_exists eq abap_false.
      message |El paquete { rv_devclass } no existe| type 'S' display like 'E'.
      clear rv_devclass.
    endif.
  endmethod.

  method confirm.
    data: lv_question type c length 400,
          lv_answer   type c length 1.

    lv_question = |¿Mover { iv_lines } objeto(s) al paquete { iv_devclass }?|.
    call function 'POPUP_TO_CONFIRM'
      exporting
        titlebar              = 'Cambiar paquete'
        text_question         = lv_question
        text_button_1         = 'Sí'
        text_button_2         = 'No'
        default_button        = '2'
        display_cancel_button = abap_false
      importing
        answer                = lv_answer
      exceptions
        text_not_found        = 1
        others                = 2.
    rv_ok = boolc( sy-subrc eq 0 and lv_answer eq '1' ).
  endmethod.

  method has_auth.
    authority-check object 'S_DEVELOP'
      id 'DEVCLASS' field iv_devclass
      id 'OBJTYPE'  field is_out-object
      id 'OBJNAME'  field is_out-obj_name
      id 'P_GROUP'  dummy
      id 'ACTVT'    field '02'.
    rv_ok = boolc( sy-subrc eq 0 ).
  endmethod.

  method move_object.
    data: lv_old type devclass.

    if cs_out-pgmid ne 'R3TR'.
      cs_out-status  = icon_led_red.
      cs_out-message = 'Solo se pueden cambiar de paquete objetos R3TR'.
      return.
    endif.

    if cs_out-devclass eq iv_devclass.
      cs_out-status  = icon_led_yellow.
      cs_out-message = |Ya está en el paquete { iv_devclass }|.
      return.
    endif.

    if has_auth( iv_devclass = cs_out-devclass is_out = cs_out ) eq abap_false
    or has_auth( iv_devclass = iv_devclass     is_out = cs_out ) eq abap_false.
      cs_out-status  = icon_led_red.
      cs_out-message = |Sin autorización S_DEVELOP para { cs_out-devclass } o { iv_devclass }|.
      return.
    endif.

    lv_old = cs_out-devclass.
    call function 'TR_TADIR_INTERFACE'
      exporting
        wi_test_modus     = abap_false
        wi_tadir_pgmid    = cs_out-pgmid
        wi_tadir_object   = cs_out-object
        wi_tadir_obj_name = cs_out-obj_name
        wi_tadir_devclass = iv_devclass
      exceptions
        others            = 1.
    if sy-subrc eq 0.
      cs_out-devclass = iv_devclass.
      cs_out-status   = icon_led_green.
      cs_out-message  = |Movido desde { lv_old }|.
    else.
      cs_out-status = icon_led_red.
      if sy-msgid is not initial.
        message id sy-msgid type 'S' number sy-msgno
                with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
                into cs_out-message.
      else.
        cs_out-message = 'Error al cambiar el paquete'.
      endif.
    endif.
  endmethod.

endclass.

*----------------------------------------------------------------------*
* Pantalla de selección
*----------------------------------------------------------------------*
selection-screen begin of block sel with frame title text-sel.
select-options: s_pgmid  for tadir-pgmid default 'R3TR',
                s_object for tadir-object,
                s_objnm  for tadir-obj_name,
                s_devcl  for tadir-devclass,
                s_author for tadir-author,
                s_srcsys for tadir-srcsystem.
parameters:     p_max    type i default 5000.
selection-screen end of block sel.

include zalv_sel_scr_var.

*----------------------------------------------------------------------*
* Proceso
*----------------------------------------------------------------------*
start-of-selection.
  data: lt_out type tyt_out.

  select *
    from tadir
   where pgmid     in @s_pgmid
     and object    in @s_object
     and obj_name  in @s_objnm
     and devclass  in @s_devcl
     and author    in @s_author
     and srcsystem in @s_srcsys
   order by pgmid, object, obj_name
    into corresponding fields of table @lt_out
    up to @p_max rows.

  if lt_out is initial.
    message 'No se encontraron objetos' type 'S' display like 'W'.
    return.
  endif.
  if p_max gt 0 and lines( lt_out ) ge p_max.
    message |Se muestran solo los primeros { p_max } objetos| type 'S' display like 'W'.
  endif.

  data(ref_alv) = new lcl_alv( ).
  ref_alv->set_ref_data( ref #( lt_out ) ).
  ref_alv->set_variant( variant = variant ).
  ref_alv->show( ).
