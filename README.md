# next186lite_graphics_gremlin
Next186 PC-XT con Graphics Gremlin de @schlae (CGA + Tandy)

Port inicial a ZX-Uno: DistWave

Integración de Graphics Gremlin: @spark2k06

Integración de rutinas de vídeo CGA a partir de la BIOS del proyecto Micro8088 de @skiselev: @spark2k06

### Atajos de teclado especiales

* CTRL + ALT + Bloq Despl -> Cambio a Verde - Ambar - B&W (Simulación de monitor monocromático)
* CTRL + ALT + KeyPad - -> Throttle Down
* CTRL + ALT + KeyPad + -> Velocidad normal a 12MHz
 

### Demostración

[![Alt text](https://lh3.googleusercontent.com/pw/AM-JKLX92yZDX6OK9YoDzmZlH4BPxe6ohA4OumpBptazThx63qNRZE2XzxVzdXzGxCjQ8lK8GZCelAGcl-KbOW0uiCNyoKuZJsdzmzQ6ygMnYoePemKOKn1Oh2lI2IVHq8nC15mtlKdAwJ6A2rRcph_fmI94_A=w1174-h652-no)](https://www.youtube.com/watch?v=hjJ8X5TZxq4)



### TODO

* Depuración de software y juegos para la mejora continua de la BIOS y el core.
* Integración del módulo de video compuesto del proyecto Graphics Gremlin de @schlae.
* Revisar por qué la señal de VGA generada por el módulo de la Graphics Gremlin no funciona en algunos monitores. Ejemplo: FLATRON M1917A
* Mejora y corrección continua de otros fallos.

### Tareas descartadas

* Eliminación completa de la cache utilizada por el Next186.
(La implementación de la caché y la BIU en el Next186 son excesivamente complejas, cualquier intento de manipulación resulta infructuosa, desestabilizando todo el sistema)

# Historial de cambios

### ZXUno PCXT CGA (Release 3)

* Adaptacion del modulo CGA para aceptar accesos de 16 bits a los registros de ésta, para tener compatibilidad con Next186. Son accesos de tipo OUT DX, AX. Ahora funciona correctamente el juego PAKU PAKU. Gracias gyurco por las ideas acerca del modo especial de texto que utiliza el juego.

* Actualizacion del modulo JTOPL2

### ZXUno PCXT CGA (Release 2)

Fix en la cache de instrucciones que soluciona glitches graficos en varios juegos de Dinamic, como Army Moves, Freddy Hardest y Capitan Trueno, entre otros. Gracias gyurco por el aporte.

### ZXUno PCXT CGA (Release 1)

Versión estable y cierre del primer ciclo de desarrollo. Al no ser sencilla la eliminación de la cache por importante dependencia con el funcionamiento del Next186, en el futuro se valorará la posibilidad de sustituirlo por el proyecto MCL86 de @MicroCoreLabs, con idea de lograr un core de ciclo exacto con un 8088, y modos de funcionamiento turbo opcionales.

Se han llevado a cabo las siguientes mejoras y correcciones:

* Corrección de fallo de teclado al reiniciar con CTRL + ALT + DEL
* 80186 a 12Mhz por defecto, en lugar de 4.77Mhz
* Opción Throttle Down con CTRL + ALT + [-], para volver al modo normal CTRL + ALT + [+]... útil para juegos antiguos que funcionan muy rápido. Al reinicio vuelve al modo normal automáticamente.

A partir de este momento sólo se actualizará el core para trasladar mejoras de proyectos en los que está basado, si hubiesen novedades destacables: Graphics Gremlin o JTOPL2

### ZXUno PCXT CGA (Beta 0.5)

* Corrección de timings de instanciado del modulo de JTOPL2
* Corrección de timings de instanciado del modulo de teclado, ya se vuelven a detectar todos los teclados.
* Mismo comportamiento que un 8086/80186 con PUSH SP, correcta identificación del modelo de CPU por parte de los programas.

### ZXUno PCXT CGA (Beta 0.4)

* Muchas correcciones, a nivel de timer, pc speaker, cpu, etc... gracias al fork de VGA para Mist de gyurco
* Soporte Adlib gracias al módulo de OPL2 desarrollado por @jotego (jtopl2)
* Velocidad de procesador seleccionable con CTRL + ALT + Keypad (+ o -): 4.77Mhz (Inicial), 9.54Mhz y 19,08Mhz, con base del bus y funcionamiento de la cache a 4.77MHz
* El cambio de salida de color monocromático a color ahora se realiza con CTRL + ALT + Bloq Despl, en lugar de sólo Bloq Despl

### ZXUno PCXT CGA (Beta 0.3)

* Corrección del fallo de la primera línea fantasma visible en modo texto.
* Compatibilidad con tarjetas de memoria SD estandar, menores de 4GB.

### ZXUno PCXT CGA (Beta 0.2)

* Refactorización, unificación y limpieza de ficheros del proyecto.
* 1MB de memoria expandida (EMS) compatible con el driver LTEMM de Lo-Tech ligeramente modificado.

### ZXUno PCXT CGA (Beta 0.1)

* Primera versión Beta.
* Versión de 2MB de SRAM con direccionamiento de 1MB.
