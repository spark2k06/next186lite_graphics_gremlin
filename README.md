# next186lite_graphics_gremlin
Next186 PC-XT con Graphics Gremlin de @schlae (CGA + Tandy)

Port inicial a ZX-Uno: DistWave

Integración de Graphics Gremlin: @spark2k06

Integración de rutinas de vídeo CGA a partir de la BIOS del proyecto Micro8088 de @skiselev: @spark2k06

### Atajos de teclado especiales

* Bloq Despl: Cambio a Verde - Ambar - B&W (Simulación de monitor monocromático)

### Demostración

[![Alt text](https://i9.ytimg.com/vi_webp/nYM2x__3_P4/sddefault.webp?v=61ab29b0&sqp=CKD4rI0G&rs=AOn4CLBAn8ZRCPZ9x4Pg56CHQO5mt0UqwA)](https://www.youtube.com/watch?v=nYM2x__3_P4)

### TODO

* Depuración de software y juegos para la mejora continua de la BIOS y el core.
* Eliminación completa de la cache utilizada por el Next186.
* Si cabe, integración del modulo JTOPL2 de @jotego para dar soporte a Adlib cuando esté disponible.
* Integración del módulo de video compuesto del proyecto Graphics Gremlin de @schlae.
* Revisar por qué la señal de VGA generada por el módulo de la Graphics Gremlin no funciona en algunos monitores. Ejemplo: FLATRON M1917A
* Mejora y corrección continua de otros fallos.

# Historial de cambios

### ZXUno PCXT CGA (Beta 0.2)

* Refactorización, unificación y limpieza de ficheros del proyecto.
* 1MB de memoria expandida (EMS) compatible con el driver LTEMM de Lo-Tech ligeramente modificado.

### ZXUno PCXT CGA (Beta 0.1)

* Primera versión Beta.
* Versión de 2MB de SRAM con direccionamiento de 1MB.
