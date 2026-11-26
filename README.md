# Bernabéu Store: Sistema de Ventas e Inventario

**Materia:** Lenguajes de Interfaz (Unidad 3)  
**Autores:** Jesus Eduardo Diaz Gastelum y Alexander Gonzalez Can  
**Entorno:** MASM x86 (32 bits) + Irvine32 en Visual Studio  

---

## 1. Informe del Proyecto

### Negocio elegido y operación del sistema
El proyecto **Bernabéu Store** implementa un sistema de consola orientado a la venta de artículos deportivos y de tienda (camisetas, balones, gorras, sudaderas, calcetines, mochilas, etc.). Administra hasta 10 productos mediante un menú repetitivo que permite registrar artículos, consultar el inventario, buscar por código, recibir mercancía, realizar ventas, mostrar el resumen general y guardar o cargar el catálogo desde disco.

Cada producto requiere un código único con formato `ABC-123` (tres letras mayúsculas, un guion y tres dígitos), nombre de 1 a 25 caracteres, precio entre `$0.01` y `$9999.99 MXN` y existencia inicial de `0` a `100` unidades. Las cantidades de entrada y venta se validan como enteros mayores que cero, y al salir el programa pregunta si deseas guardar cuando existen cambios sin guardar (`sucio = 1`).

### Regla adicional del negocio
* **Alerta de existencia mínima (`stock <= 5`):** al confirmar una venta, si la existencia restante del producto queda menor o igual a 5 unidades, el sistema muestra en consola el mensaje `[AVISO: Quedan pocas unidades en existencia]` para advertir la necesidad de reabastecer.

### Organización de datos en memoria y formato del archivo
En memoria, el catálogo reserva `MAX_PRODS * TAM_REG` bytes (`10 * 40 = 400` bytes) para registros de 40 bytes cada uno (`codigo[0..7]`, `nombre[8..33]`, `precio[34..37]` en centavos `DWORD`, y `stock[38..39]` como `WORD`). Los recorridos por el arreglo y la localización de registros se realizan mediante `ESI`. Los precios se capturan con `ReadString`, se convierten a centavos enteros y se imprimen con rutinas propias (`ImprimirEntero` e `ImprimirImporte`) sin usar `ReadDec`, `ReadInt`, `ParseDecimal32`, `WriteDec` ni `WriteHex`.

La persistencia se guarda en `inventario_datos.dat` con encabezado de 8 bytes (`MARCA = "INV1"` en `31564E49h` + `cntProds` `DWORD`) seguido de `cntProds * 40` bytes. `CargarDatosDisco` valida tamaño, firma, rango de cada registro y ausencia de códigos repetidos (`CodigosRepetidos`) antes de reemplazar `dbCatalogo`, conservando los datos previos si el archivo no existe o está dañado.

### Decisiones técnicas y fuentes consultadas
Guardar los importes en centavos enteros evita errores de representación de punto flotante en multiplicaciones de venta, valor total del inventario e ingresos acumulados, comprobando desbordamientos antes de aplicar cambios. Se consultaron Kip Irvine (*Assembly Language for x86 Processors* y referencia de `Irvine32`) y la documentación oficial de Microsoft sobre MASM (`ml.exe`) y proyectos de Visual Studio.

---

## 2. Versión de la Unidad 3

### Tabla de antes y después

| Parte del programa | Problema detectado | Cambio realizado | Beneficio |
| :--- | :--- | :--- | :--- |
| Captura de texto y mensajes en consola | Repetición de `mov EDX, OFFSET ... / call WriteString` y `mov EDX, OFFSET bufferStr / mov ECX, ... / call ReadString` en varios procedimientos | Se crearon las macros `PrintStr` y `LeerBuffer` (con etiqueta `LOCAL lb_listo`) | Menos código repetido y lectura más limpia en el flujo del menú y validaciones |
| Copia de bloques de memoria | Copiado manual de bytes entre buffers temporales y registros con ciclos o repetidos dispersos | Se añadió la macro `CopiarBloque srcOff, dstOff, cantBytes` con `cld` / `rep movsb` | Centraliza la copia de cadenas/bloques de tamaño fijo con menor riesgo de error |
| Búsqueda y validación de código en flujos de menú | Varias opciones repetían pedir código, validar `ABC-123` y buscar en el catálogo | Se centralizó en `PedirYBuscar` reutilizando `ValidarCodigoABC` y `BuscarPorCodigo` | Evita duplicar lógica de validación y mensajes de error entre opciones |
| Conservación de registros y retorno de valores | Riesgo de alterar registros del llamador o perder valores devueltos al manipular la pila manualmente | Se aplicó `USES` en los procedimientos, dejando fuera de `USES` los registros de salida (`EAX`, `ESI`) | Mantiene la pila equilibrada al retornar y protege el estado de los registros no devueltos |

### Fragmentos representativos (en `main.asm`)

**1. Macro con `LOCAL` y sus puntos de uso (`main.asm`):**
```asm
LeerBuffer MACRO maxLen
    LOCAL lb_listo
    mov EDX, OFFSET bufferStr
    mov ECX, maxLen
    call ReadString
lb_listo:
ENDM
