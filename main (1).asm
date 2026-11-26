; ==============================================================================
; Proyecto Unidad 3 - Sistema de Inventario y Ventas (Bernabeu Store)
; Alumno: Jesus Eduardo Diaz Gastelum y Alexander Gonzalez Can
; Materia: Lenguajes de Interfaz
; Regla del negocio: alerta de existencia minima (stock <= 5 despues de vender)
; ==============================================================================

INCLUDE Irvine32.inc

; --- Constantes ---
MAX_PRODS       EQU 10
TAM_REG         EQU 40          ; tamano de cada registro de producto
TAM_CODIGO      EQU 8           ; ABC-123 + 0
TAM_NOMBRE      EQU 26          ; 25 chars + 0
OFS_NOM         EQU 8           ; offset del nombre dentro del registro
OFS_PRE         EQU 34          ; offset del precio (DWORD, centavos)
OFS_STK         EQU 38          ; offset de la existencia (WORD)
PRECIO_MAX      EQU 999999      ; 9999.99 en centavos
STOCK_MAX       EQU 100
STOCK_MIN       EQU 5
MARCA           EQU 31564E49h   ; "INV1" en el archivo
ARCH_MAX        EQU 408         ; 8 bytes de encabezado + 10 * 40

; --- Macros ---
; Imprime una cadena terminada en 0 usando WriteString
PrintStr MACRO offsetMsg
    mov EDX, OFFSET offsetMsg
    call WriteString
ENDM

; Lee una linea en bufferStr usando ReadString (usa LOCAL para etiqueta interna)
LeerBuffer MACRO maxLen
    LOCAL lb_listo
    mov EDX, OFFSET bufferStr
    mov ECX, maxLen
    call ReadString
lb_listo:
ENDM

; Copia un bloque de bytes de origen a destino con rep movsb
CopiarBloque MACRO srcOff, dstOff, cantBytes
    mov ESI, OFFSET srcOff
    mov EDI, OFFSET dstOff
    mov ECX, cantBytes
    rep movsb
ENDM

.data
    txtTitulo       BYTE 13,10, "=== SISTEMA DE VENTAS E INVENTARIO (BERNABEU STORE) ===", 13,10, 0
    txtMenu         BYTE 13,10, "1. Registrar producto", 13,10,
                         "2. Ver inventario", 13,10,
                         "3. Buscar por codigo", 13,10,
                         "4. Recibir mercancia", 13,10,
                         "5. Realizar venta", 13,10,
                         "6. Mostrar resumen", 13,10,
                         "7. Guardar", 13,10,
                         "8. Salir", 13,10,
                         "Elige una opcion: ", 0

    txtPedirCod     BYTE "Codigo (ej. ABC-123): ", 0
    txtPedirNom     BYTE "Nombre del producto (max 25): ", 0
    txtPedirPrecio  BYTE "Precio en MXN (ej. 185.50): ", 0
    txtPedirStock   BYTE "Existencia inicial (0-100): ", 0
    txtPedirCant    BYTE "Cantidad (entero mayor que 0): ", 0

    txtErrLmt       BYTE "Error: Ya se alcanzaron los 10 productos maximos.", 13,10, 0
    txtErrDup       BYTE "Error: Ese codigo ya esta registrado.", 13,10, 0
    txtErrVal       BYTE "Error: Formato invalido o fuera de rango.", 13,10, 0
    txtErrNoFind    BYTE "Error: Producto no encontrado en el inventario.", 13,10, 0
    txtErrStk       BYTE "Error: Stock insuficiente o limite de 100 rebasado.", 13,10, 0
    txtErrDesb      BYTE "Error: Desbordamiento en el calculo.", 13,10, 0

    txtOkReg        BYTE "Alta exitosa.", 13,10, 0
    txtOkAct        BYTE "Stock actualizado.", 13,10, 0
    txtOkVenta      BYTE "Venta aplicada. Total pagado: ", 0
    txtAlertaStock  BYTE " [AVISO: Quedan pocas unidades en existencia]", 13,10, 0

    txtEncabezado   BYTE 13,10, "--- LISTADO DE PRODUCTOS EN MEMORIA ---", 13,10, 0
    txtVacio        BYTE "No hay productos registrados.", 13,10, 0
    txtResumenHead  BYTE 13,10, "=== REPORTE GENERAL ===", 13,10, 0
    txtLblUnits     BYTE "Total de piezas en bodega: ", 0
    txtLblValInv    BYTE "Valor total del inventario: ", 0
    txtLblIngresos  BYTE "Ingresos totales de la sesion: ", 0

    txtSep          BYTE " | ", 0
    txtPzas         BYTE " pzas", 0
    txtMXN          BYTE " MXN", 0

    txtPregGuardar  BYTE "Hay cambios sin guardar. Guardar antes de salir? (S/N): ", 0

    fileNombre      BYTE "inventario_datos.dat", 0
    txtFileOk       BYTE "Datos guardados en disco correctamente.", 13,10, 0
    txtFileErrG     BYTE "Error: No se pudo guardar el archivo completo.", 13,10, 0
    txtCargaOk      BYTE "Catalogo cargado desde disco.", 13,10, 0
    txtCargaNo      BYTE "Aviso: no hay archivo previo, se inicia con catalogo vacio.", 13,10, 0
    txtCargaMal     BYTE "Aviso: archivo danado o invalido, se inicia con catalogo vacio.", 13,10, 0

    ; Memoria principal: 10 productos * 40 bytes
    ; Registro: codigo[0..7], nombre[8..33], precio[34..37], stock[38..39]
    dbCatalogo      BYTE MAX_PRODS * TAM_REG DUP(0)
    cntProds        DWORD 0
    totalIngresos   DWORD 0
    sucio           BYTE 0              ; 1 = hay cambios sin guardar

    ; Buffers auxiliares
    bufferStr       BYTE 30 DUP(0)
    tmpCod          BYTE TAM_CODIGO DUP(0)
    tmpNom          BYTE TAM_NOMBRE DUP(0)
    tmpPrecio       DWORD 0
    tmpStock        DWORD 0
    numBuf          BYTE 12 DUP(0)
    bufArch         BYTE ARCH_MAX DUP(0)
    handleArch      DWORD 0

.code
main PROC
    call CargarDatosDisco

menu_loop:
    PrintStr txtTitulo
    PrintStr txtMenu

    LeerBuffer 29
    cmp EAX, 1                  ; solo se acepta un caracter
    jne menu_loop
    mov AL, [bufferStr]

    cmp AL, '1'
    je hacer_alta
    cmp AL, '2'
    je hacer_consulta
    cmp AL, '3'
    je hacer_busqueda
    cmp AL, '4'
    je hacer_entrada
    cmp AL, '5'
    je hacer_venta
    cmp AL, '6'
    je hacer_resumen
    cmp AL, '7'
    je hacer_guardar
    cmp AL, '8'
    je salir_prog
    jmp menu_loop

hacer_alta:
    call RegistrarProd
    jmp menu_loop
hacer_consulta:
    call ConsultarInventario
    jmp menu_loop
hacer_busqueda:
    call BuscarProducto
    jmp menu_loop
hacer_entrada:
    call RecibirMercancia
    jmp menu_loop
hacer_venta:
    call VenderProducto
    jmp menu_loop
hacer_resumen:
    call MostrarResumen
    jmp menu_loop
hacer_guardar:
    call GuardarDatosDisco
    jmp menu_loop

salir_prog:
    cmp sucio, 0
    je terminar
    PrintStr txtPregGuardar
    LeerBuffer 29
    cmp EAX, 1
    jne terminar
    mov AL, [bufferStr]
    or AL, 20h                  ; a minuscula
    cmp AL, 's'
    jne terminar
    call GuardarDatosDisco
terminar:
    exit
main ENDP


; ==============================================================================
; RegistrarProd
; Entrada: ninguna (captura por teclado)
; Salida:  agrega un producto al catalogo si todo es valido; si no, no cambia nada
; Modifica: ninguno (USES conserva EAX, EBX, ECX, EDX, ESI, EDI)
; ==============================================================================
RegistrarProd PROC USES EAX EBX ECX EDX ESI EDI
    cld

    cmp cntProds, MAX_PRODS
    jae rp_lleno

    ; 1. Codigo
    PrintStr txtPedirCod
    LeerBuffer 29
    mov EDX, OFFSET bufferStr
    call ValidarCodigoABC
    jc rp_formato
    call BuscarPorCodigo        ; EDX sigue apuntando a bufferStr
    cmp EAX, 1
    je rp_duplicado
    CopiarBloque bufferStr, tmpCod, TAM_CODIGO

    ; 2. Nombre (1 a 25 caracteres)
    PrintStr txtPedirNom
    LeerBuffer 29
    cmp EAX, 0
    je rp_formato
    cmp EAX, 25
    ja rp_formato
    mov EBX, EAX                ; longitud
    mov EDI, OFFSET tmpNom      ; limpiar el temporal para que quede el 0 final
    mov ECX, TAM_NOMBRE
    xor AL, AL
    rep stosb
    mov ESI, OFFSET bufferStr
    mov EDI, OFFSET tmpNom
    mov ECX, EBX
    rep movsb

    ; 3. Precio
    PrintStr txtPedirPrecio
    LeerBuffer 29
    mov EDX, OFFSET bufferStr
    call ParsearPrecio
    jc rp_formato
    mov tmpPrecio, EAX

    ; 4. Existencia (0 a 100)
    PrintStr txtPedirStock
    LeerBuffer 29
    mov EDX, OFFSET bufferStr
    call ParsearEntero
    jc rp_formato
    cmp EAX, STOCK_MAX
    ja rp_formato
    mov tmpStock, EAX

    ; 5. Todo valido: copiar al catalogo
    mov EAX, cntProds
    imul EAX, EAX, TAM_REG
    mov ESI, OFFSET dbCatalogo
    add ESI, EAX                ; ESI = registro nuevo
    mov EDI, ESI
    push ESI
    mov ESI, OFFSET tmpCod
    mov ECX, TAM_CODIGO
    rep movsb
    mov ESI, OFFSET tmpNom
    mov ECX, TAM_NOMBRE
    rep movsb                   ; EDI queda en +34
    pop ESI
    mov EAX, tmpPrecio
    mov [ESI + OFS_PRE], EAX
    mov EAX, tmpStock
    mov [ESI + OFS_STK], AX
    inc cntProds
    mov sucio, 1

    PrintStr txtOkReg
    jmp rp_fin

rp_lleno:
    PrintStr txtErrLmt
    jmp rp_fin
rp_formato:
    PrintStr txtErrVal
    jmp rp_fin
rp_duplicado:
    PrintStr txtErrDup

rp_fin:
    ret
RegistrarProd ENDP


; ==============================================================================
; MostrarRegistro
; Entrada: ESI = direccion del registro
; Salida:  imprime una linea con codigo, nombre, precio y existencia
; Modifica: ninguno (USES conserva EAX y EDX)
; ==============================================================================
MostrarRegistro PROC USES EAX EDX
    mov EDX, ESI
    call WriteString
    PrintStr txtSep

    mov EDX, ESI
    add EDX, OFS_NOM
    call WriteString
    PrintStr txtSep

    mov EAX, [ESI + OFS_PRE]
    call ImprimirImporte
    PrintStr txtSep

    movzx EAX, WORD PTR [ESI + OFS_STK]
    call ImprimirEntero
    PrintStr txtPzas
    call Crlf

    ret
MostrarRegistro ENDP


; ==============================================================================
; ConsultarInventario
; Entrada: ninguna
; Salida:  lista todos los productos
; Modifica: ninguno (USES conserva ECX, EDX, ESI)
; ==============================================================================
ConsultarInventario PROC USES ECX EDX ESI
    PrintStr txtEncabezado

    mov ECX, cntProds
    cmp ECX, 0
    jne ci_hay
    PrintStr txtVacio
    jmp ci_fin

ci_hay:
    mov ESI, OFFSET dbCatalogo
ci_bucle:
    call MostrarRegistro
    add ESI, TAM_REG
    dec ECX
    jnz ci_bucle

ci_fin:
    ret
ConsultarInventario ENDP


; ==============================================================================
; BuscarProducto  (opcion de menu: buscar por codigo)
; Entrada: ninguna
; Salida:  muestra el producto si existe
; Modifica: ninguno (USES conserva EAX y ESI)
; ==============================================================================
BuscarProducto PROC USES EAX ESI
    call PedirYBuscar
    cmp EAX, 0
    je bpr_fin
    call MostrarRegistro
bpr_fin:
    ret
BuscarProducto ENDP


; ==============================================================================
; RecibirMercancia
; Entrada: ninguna
; Salida:  suma unidades al producto sin pasar de 100
; Modifica: ninguno (USES conserva EAX, EBX, EDX, ESI)
; ==============================================================================
RecibirMercancia PROC USES EAX EBX EDX ESI
    call PedirYBuscar
    cmp EAX, 0
    je rm_fin

    call PedirCantidad          ; EAX = cantidad, CF=1 si error
    jc rm_fin

    movzx EBX, WORD PTR [ESI + OFS_STK]
    add EBX, EAX
    cmp EBX, STOCK_MAX
    ja rm_exceso

    mov [ESI + OFS_STK], BX
    mov sucio, 1
    PrintStr txtOkAct
    jmp rm_fin

rm_exceso:
    PrintStr txtErrStk

rm_fin:
    ret
RecibirMercancia ENDP


; ==============================================================================
; VenderProducto
; Entrada: ninguna
; Salida:  descuenta existencias y suma el importe a totalIngresos.
;          Si algo falla, no se modifica nada (todo se calcula antes de guardar).
; Regla del negocio: si despues de vender quedan <= STOCK_MIN piezas, avisa.
; Modifica: ninguno (USES conserva EAX, EBX, ECX, EDX, ESI)
; ==============================================================================
VenderProducto PROC USES EAX EBX ECX EDX ESI
    call PedirYBuscar
    cmp EAX, 0
    je vp_fin

    call PedirCantidad
    jc vp_fin

    movzx EBX, WORD PTR [ESI + OFS_STK]
    cmp EAX, EBX
    ja vp_sin_stock

    mov ECX, EAX                ; ECX = cantidad vendida
    mov EAX, [ESI + OFS_PRE]
    mul ECX                     ; EDX:EAX = precio * cantidad
    jc vp_desborde
    mov EDX, totalIngresos
    add EDX, EAX
    jc vp_desborde

    ; ya todo salio bien, ahora si se actualiza
    mov totalIngresos, EDX
    sub EBX, ECX
    mov [ESI + OFS_STK], BX
    mov sucio, 1

    PrintStr txtOkVenta
    call ImprimirImporte        ; EAX = importe
    call Crlf

    cmp EBX, STOCK_MIN
    ja vp_fin
    PrintStr txtAlertaStock
    jmp vp_fin

vp_sin_stock:
    PrintStr txtErrStk
    jmp vp_fin
vp_desborde:
    PrintStr txtErrDesb

vp_fin:
    ret
VenderProducto ENDP


; ==============================================================================
; MostrarResumen
; Entrada: ninguna
; Salida:  piezas, valor del inventario e ingresos de la sesion
; Modifica: ninguno (USES conserva EAX, EBX, ECX, EDX, ESI, EDI)
; ==============================================================================
MostrarResumen PROC USES EAX EBX ECX EDX ESI EDI
    PrintStr txtResumenHead

    mov ECX, cntProds
    mov ESI, OFFSET dbCatalogo
    xor EBX, EBX                ; piezas
    xor EDI, EDI                ; valor en centavos
    cmp ECX, 0
    je rs_imprimir

rs_bucle:
    movzx EAX, WORD PTR [ESI + OFS_STK]
    add EBX, EAX
    mul DWORD PTR [ESI + OFS_PRE]   ; EDX:EAX = stock * precio
    add EDI, EAX
    add ESI, TAM_REG
    dec ECX
    jnz rs_bucle

rs_imprimir:
    PrintStr txtLblUnits
    mov EAX, EBX
    call ImprimirEntero
    call Crlf

    PrintStr txtLblValInv
    mov EAX, EDI
    call ImprimirImporte
    call Crlf

    PrintStr txtLblIngresos
    mov EAX, totalIngresos
    call ImprimirImporte
    call Crlf

    ret
MostrarResumen ENDP


; ==============================================================================
; PedirYBuscar
; Entrada: ninguna (pide el codigo)
; Salida:  EAX = 1 si lo encontro (ESI = registro), EAX = 0 si no (ya mostro el error)
; Modifica: EAX, ESI (quedan fuera de USES; conserva ECX y EDX)
; ==============================================================================
PedirYBuscar PROC USES ECX EDX
    PrintStr txtPedirCod
    LeerBuffer 29
    mov EDX, OFFSET bufferStr
    call ValidarCodigoABC
    jc pb_formato
    call BuscarPorCodigo
    cmp EAX, 0
    jne pb_fin
    PrintStr txtErrNoFind
    jmp pb_fin

pb_formato:
    PrintStr txtErrVal
    xor EAX, EAX

pb_fin:
    ret
PedirYBuscar ENDP


; ==============================================================================
; PedirCantidad
; Entrada: ninguna
; Salida:  EAX = cantidad (>0), CF = 0 ; si es invalida muestra error y CF = 1
; Modifica: EAX (queda fuera de USES; conserva ECX y EDX)
; ==============================================================================
PedirCantidad PROC USES ECX EDX
    PrintStr txtPedirCant
    LeerBuffer 29
    mov EDX, OFFSET bufferStr
    call ParsearEntero
    jc pc_mal
    cmp EAX, 0
    je pc_mal
    clc
    jmp pc_fin

pc_mal:
    PrintStr txtErrVal
    stc

pc_fin:
    ret
PedirCantidad ENDP


; ==============================================================================
; ValidarCodigoABC
; Entrada: EDX = cadena terminada en 0
; Salida:  CF = 0 si es AAA-999 exacto (7 caracteres), CF = 1 si no
; Modifica: ninguno (solo banderas; USES conserva EAX, ECX, ESI)
; ==============================================================================
ValidarCodigoABC PROC USES EAX ECX ESI
    mov ESI, EDX
    mov ECX, 3
vc_letras:
    mov AL, [ESI]
    cmp AL, 'A'
    jb vc_mal
    cmp AL, 'Z'
    ja vc_mal
    inc ESI
    dec ECX
    jnz vc_letras

    cmp BYTE PTR [ESI], '-'
    jne vc_mal
    inc ESI

    mov ECX, 3
vc_nums:
    mov AL, [ESI]
    cmp AL, '0'
    jb vc_mal
    cmp AL, '9'
    ja vc_mal
    inc ESI
    dec ECX
    jnz vc_nums

    cmp BYTE PTR [ESI], 0       ; no puede haber mas caracteres
    jne vc_mal
    clc
    jmp vc_fin
vc_mal:
    stc
vc_fin:
    ret
ValidarCodigoABC ENDP


; ==============================================================================
; ParsearEntero
; Entrada: EDX = cadena terminada en 0
; Salida:  EAX = valor, CF = 0 ; CF = 1 si esta vacia, tiene no-digitos o
;          pasa de 100000 (esto evita desbordamientos)
; Modifica: EAX (queda fuera de USES; conserva EBX, ECX, ESI)
; ==============================================================================
ParsearEntero PROC USES EBX ECX ESI
    mov ESI, EDX
    xor EAX, EAX
    xor ECX, ECX                ; cuenta de digitos

pe_ciclo:
    movzx EBX, BYTE PTR [ESI]
    cmp BL, 0
    je pe_fin_cadena
    cmp BL, '0'
    jb pe_mal
    cmp BL, '9'
    ja pe_mal
    sub BL, '0'
    imul EAX, EAX, 10
    add EAX, EBX
    inc ECX
    inc ESI
    cmp EAX, 100000
    ja pe_mal
    jmp pe_ciclo

pe_fin_cadena:
    cmp ECX, 0                  ; cadena vacia
    je pe_mal
    clc
    jmp pe_fin
pe_mal:
    stc
pe_fin:
    ret
ParsearEntero ENDP


; ==============================================================================
; ParsearPrecio
; Entrada: EDX = cadena terminada en 0 (ej. "185", "185.5", "12.05")
; Salida:  EAX = centavos, CF = 0 ; CF = 1 si es invalida o fuera de 0.01-9999.99
; Modifica: EAX (queda fuera de USES; conserva EBX, ECX, ESI)
; ==============================================================================
ParsearPrecio PROC USES EBX ECX ESI
    mov ESI, EDX
    xor EAX, EAX                ; pesos
    xor ECX, ECX                ; digitos enteros

pp_entero:
    movzx EBX, BYTE PTR [ESI]
    cmp BL, 0
    je pp_sin_punto
    cmp BL, '.'
    je pp_punto
    cmp BL, '0'
    jb pp_mal
    cmp BL, '9'
    ja pp_mal
    sub BL, '0'
    imul EAX, EAX, 10
    add EAX, EBX
    inc ECX
    inc ESI
    cmp EAX, 9999
    ja pp_mal
    jmp pp_entero

pp_sin_punto:
    cmp ECX, 0
    je pp_mal
    imul EAX, EAX, 100          ; pesos a centavos
    jmp pp_rango

pp_punto:
    cmp ECX, 0                  ; ".50" no se acepta
    je pp_mal
    inc ESI
    imul EAX, EAX, 100
    xor ECX, ECX                ; ahora cuenta decimales

pp_decimal:
    movzx EBX, BYTE PTR [ESI]
    cmp BL, 0
    je pp_fin_dec
    cmp BL, '0'
    jb pp_mal
    cmp BL, '9'
    ja pp_mal
    sub BL, '0'
    inc ECX
    cmp ECX, 2                  ; tercer decimal = rechazo
    ja pp_mal
    cmp ECX, 1
    jne pp_segundo
    imul EBX, EBX, 10           ; primer decimal vale decenas de centavo
pp_segundo:
    add EAX, EBX
    inc ESI
    jmp pp_decimal

pp_fin_dec:
    cmp ECX, 0                  ; "185." no se acepta
    je pp_mal

pp_rango:
    cmp EAX, 1
    jb pp_mal
    cmp EAX, PRECIO_MAX
    ja pp_mal
    clc
    jmp pp_fin
pp_mal:
    stc
pp_fin:
    ret
ParsearPrecio ENDP


; ==============================================================================
; ImprimirEntero   (reemplaza a WriteDec)
; Entrada: EAX = numero sin signo
; Salida:  lo imprime en decimal
; Modifica: ninguno (USES conserva EAX, EBX, EDX, ESI)
; Idea: dividir entre 10; el residuo es el digito (se suma '0' para ASCII).
; Los digitos salen al reves, por eso se llena numBuf desde el final.
; ==============================================================================
ImprimirEntero PROC USES EAX EBX EDX ESI
    mov ESI, OFFSET numBuf + 11
    mov BYTE PTR [ESI], 0
    mov EBX, 10
ie_digito:
    xor EDX, EDX
    div EBX                     ; EAX = cociente, EDX = residuo
    add DL, '0'
    dec ESI
    mov [ESI], DL
    cmp EAX, 0
    jne ie_digito

    mov EDX, ESI
    call WriteString

    ret
ImprimirEntero ENDP


; ==============================================================================
; ImprimirImporte
; Entrada: EAX = centavos
; Salida:  imprime pesos.centavos MXN (con dos decimales, sin salto de linea)
; Modifica: ninguno (USES conserva EAX, EBX, EDX)
; ==============================================================================
ImprimirImporte PROC USES EAX EBX EDX
    mov EBX, 100
    xor EDX, EDX
    div EBX                     ; EAX = pesos, EDX = centavos
    call ImprimirEntero
    mov AL, '.'
    call WriteChar

    cmp EDX, 10
    jae ii_decimales
    mov AL, '0'                 ; residuo de 5 se muestra como 05
    call WriteChar
ii_decimales:
    mov EAX, EDX
    call ImprimirEntero
    PrintStr txtMXN

    ret
ImprimirImporte ENDP


; ==============================================================================
; BuscarPorCodigo
; Entrada: EDX = codigo terminado en 0 (ya validado)
; Salida:  EAX = 1 y ESI = registro si lo encuentra; EAX = 0 si no
;          (en ese caso ESI no es util)
; Modifica: EAX, ESI (quedan fuera de USES; conserva EBX y ECX)
; ==============================================================================
BuscarPorCodigo PROC USES EBX ECX
    mov ECX, cntProds
    cmp ECX, 0
    je bc_no
    mov ESI, OFFSET dbCatalogo

bc_registro:
    xor EBX, EBX
bc_char:
    mov AL, [ESI + EBX]
    cmp AL, [EDX + EBX]
    jne bc_siguiente
    inc EBX
    cmp EBX, TAM_CODIGO         ; compara los 8 bytes, incluido el 0
    jb bc_char
    mov EAX, 1
    jmp bc_fin

bc_siguiente:
    add ESI, TAM_REG
    dec ECX
    jnz bc_registro

bc_no:
    xor EAX, EAX
bc_fin:
    ret
BuscarPorCodigo ENDP


; ==============================================================================
; ValidarRegistro
; Entrada: ESI = registro a revisar (por ejemplo, uno leido del archivo)
; Salida:  CF = 0 si es valido, CF = 1 si no
; Modifica: ninguno (solo banderas; USES conserva EAX, EBX, EDX)
; ==============================================================================
ValidarRegistro PROC USES EAX EBX EDX
    mov EDX, ESI
    call ValidarCodigoABC
    jc vr_mal

    xor EBX, EBX                ; buscar el 0 del nombre
vr_nombre:
    cmp BYTE PTR [ESI + OFS_NOM + EBX], 0
    je vr_nombre_ok
    inc EBX
    cmp EBX, TAM_NOMBRE
    jb vr_nombre
    jmp vr_mal                  ; no tiene terminador
vr_nombre_ok:
    cmp EBX, 0
    je vr_mal

    mov EAX, [ESI + OFS_PRE]
    cmp EAX, 1
    jb vr_mal
    cmp EAX, PRECIO_MAX
    ja vr_mal

    movzx EAX, WORD PTR [ESI + OFS_STK]
    cmp EAX, STOCK_MAX
    ja vr_mal

    clc
    jmp vr_fin
vr_mal:
    stc
vr_fin:
    ret
ValidarRegistro ENDP


; ==============================================================================
; CodigosRepetidos
; Entrada: ESI = primer registro, ECX = cantidad de registros
; Salida:  CF = 1 si hay dos codigos iguales, CF = 0 si todos son distintos
; Modifica: ninguno (solo banderas; USES conserva EAX, EBX, ECX, EDX, ESI, EDI)
; ==============================================================================
CodigosRepetidos PROC USES EAX EBX ECX EDX ESI EDI
cr_externo:
    cmp ECX, 1
    jbe cr_ok                   ; ya no quedan pares por comparar
    mov EDI, ESI
    mov EDX, ECX
    dec EDX                     ; registros que siguen despues de ESI
cr_interno:
    add EDI, TAM_REG
    xor EBX, EBX
cr_char:
    mov AL, [ESI + EBX]
    cmp AL, [EDI + EBX]
    jne cr_otro
    inc EBX
    cmp EBX, TAM_CODIGO
    jb cr_char
    stc                         ; los 8 bytes coinciden: repetido
    jmp cr_fin
cr_otro:
    dec EDX
    jnz cr_interno
    add ESI, TAM_REG
    dec ECX
    jmp cr_externo

cr_ok:
    clc
cr_fin:
    ret
CodigosRepetidos ENDP


; ==============================================================================
; ARCHIVO. Formato: [MARCA "INV1" 4 bytes][cantidad 4 bytes][cantidad * 40 bytes]
; ==============================================================================

; GuardarDatosDisco
; Entrada: ninguna
; Salida:  escribe el catalogo; limpia 'sucio' solo si se escribieron todos los bytes
; Modifica: ninguno (USES conserva EAX, EBX, ECX, EDX, ESI, EDI)
GuardarDatosDisco PROC USES EAX EBX ECX EDX ESI EDI
    cld

    ; armar el buffer: encabezado + registros
    mov DWORD PTR bufArch, MARCA
    mov EAX, cntProds
    mov DWORD PTR bufArch[4], EAX
    imul EAX, EAX, TAM_REG
    mov ECX, EAX                ; bytes de catalogo
    lea EBX, [EAX + 8]          ; EBX = total a escribir
    mov ESI, OFFSET dbCatalogo
    mov EDI, OFFSET bufArch + 8
    rep movsb

    mov EDX, OFFSET fileNombre
    call CreateOutputFile       ; EAX = handle
    cmp EAX, INVALID_HANDLE_VALUE
    je gd_error

    mov handleArch, EAX
    mov EDX, OFFSET bufArch
    mov ECX, EBX
    call WriteToFile            ; EAX = bytes escritos
    cmp EAX, EBX
    jne gd_incompleto

    mov EAX, handleArch
    call CloseFile
    mov sucio, 0
    PrintStr txtFileOk
    jmp gd_fin

gd_incompleto:
    mov EAX, handleArch
    call CloseFile
gd_error:
    PrintStr txtFileErrG

gd_fin:
    ret
GuardarDatosDisco ENDP


; CargarDatosDisco
; Entrada: ninguna
; Salida:  si el archivo existe y es valido, reemplaza el catalogo.
;          Si no existe o esta danado, el catalogo queda como estaba (vacio).
; Modifica: ninguno (USES conserva EAX, EBX, ECX, EDX, ESI, EDI)
CargarDatosDisco PROC USES EAX EBX ECX EDX ESI EDI
    cld

    mov EDX, OFFSET fileNombre
    call OpenInputFile
    cmp EAX, INVALID_HANDLE_VALUE
    je cd_ausente

    mov handleArch, EAX
    mov EDX, OFFSET bufArch
    mov ECX, ARCH_MAX
    call ReadFromFile           ; EAX = bytes leidos, CF = error
    jc cd_error_lectura
    mov EBX, EAX                ; EBX = bytes leidos
    mov EAX, handleArch
    call CloseFile

    ; validar encabezado y tamano antes de tocar el catalogo
    cmp EBX, 8
    jb cd_invalido
    cmp DWORD PTR bufArch, MARCA
    jne cd_invalido
    mov ECX, DWORD PTR bufArch[4]
    cmp ECX, MAX_PRODS
    ja cd_invalido
    mov EAX, ECX
    imul EAX, EAX, TAM_REG
    add EAX, 8
    cmp EAX, EBX                ; tamano esperado = bytes leidos
    jne cd_invalido

    ; validar cada registro
    mov ESI, OFFSET bufArch + 8
    cmp ECX, 0
    je cd_copiar
cd_ciclo:
    call ValidarRegistro
    jc cd_invalido
    add ESI, TAM_REG
    dec ECX
    jnz cd_ciclo

    ; validar que no haya codigos repetidos dentro del archivo
    mov ESI, OFFSET bufArch + 8
    mov ECX, DWORD PTR bufArch[4]
    call CodigosRepetidos
    jc cd_invalido

cd_copiar:
    mov ECX, DWORD PTR bufArch[4]
    mov EAX, ECX
    imul ECX, ECX, TAM_REG
    mov ESI, OFFSET bufArch + 8
    mov EDI, OFFSET dbCatalogo
    rep movsb
    mov cntProds, EAX
    mov sucio, 0
    PrintStr txtCargaOk
    jmp cd_fin

cd_error_lectura:
    mov EAX, handleArch
    call CloseFile
cd_invalido:
    PrintStr txtCargaMal
    jmp cd_fin

cd_ausente:
    PrintStr txtCargaNo

cd_fin:
    ret
CargarDatosDisco ENDP

END main
