# zcl_pkg

Utilidades de paquetes para SAP ABAP, distribuidas con [abapGit](https://abapgit.org).

## Contenido

| Objeto | Tipo | Descripción |
|---|---|---|
| `ZPKG_TADIR` | Programa | Lista el catálogo de objetos (TADIR) y cambia de paquete los objetos seleccionados |
| `ZCL_PKG` | Clase | Esqueleto, aún sin métodos |

## Dependencias

- [zcl_alv](https://github.com/ricardopsj/zcl_alv): grilla ALV (`ZCL_ALV`, `ZALV_T_ROW`, include `ZALV_SEL_SCR_VAR`).

## ZPKG_TADIR

1. Filtra TADIR por PGMID, tipo, nombre, paquete, autor y sistema original. `Máximo de registros` limita la lectura (0 = sin límite).
2. Muestra el resultado en `ZCL_ALV`, con selección múltiple de filas.
3. El botón **Cambiar paquete** (Ctrl+F1) pide el paquete destino, valida que exista y pide confirmación.
4. Cada objeto se mueve con `TR_TADIR_INTERFACE`. Las columnas *Estado* y *Resultado* muestran el resultado por fila:
   - verde: movido;
   - amarillo: ya estaba en ese paquete;
   - rojo: error (solo se aceptan objetos `R3TR`, falta autorización o el sistema rechazó el cambio).

Autorización: `S_DEVELOP` con actividad `02` sobre el paquete de origen y el de destino.

El programa solo cambia la entrada de TADIR. No registra los objetos en una orden de transporte: para que el cambio llegue a otros sistemas, hay que incluir los objetos en una orden (por ejemplo, desde SE03 o SE80).

## Instalación

1. En SAP, abre abapGit (transacción `ZABAPGIT` o el programa `ZABAPGIT_STANDALONE`).
2. Crea un repositorio online con la URL de este repo.
3. Asigna un paquete destino, por ejemplo `ZCL_PKG`, y haz *Pull*.

## Configuración abapGit

| Opción | Valor |
|---|---|
| Idioma principal | Español (`S`) |
| Carpeta inicial | `/src/` |
| Lógica de carpetas | `PREFIX` |
