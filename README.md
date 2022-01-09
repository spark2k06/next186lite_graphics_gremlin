# next186lite_graphics_gremlin
Next186 PC-XT con Graphics Gremlin de @schlae (CGA + Tandy)

Port inicial a ZX-Uno: DistWave

Integración de Graphics Gremlin: @spark2k06

Integración de rutinas de vídeo CGA a partir de la BIOS del proyecto Micro8088 de @skiselev: @spark2k06

### Atajos de teclado especiales

* CTRL + ALT + Bloq Despl -> Cambio a Verde - Ambar - B&W (Simulación de monitor monocromático)
* CTRL + ALT + KeyPad + -> Sube la velocidad del procesador 
* CTRL + ALT + KeyPad - -> Baja la velocidad del procesador 

### Demostración

[![Alt text](https://lh3.googleusercontent.com/pw/AM-JKLUV9PB55D0MieEYQAd9cCj-9bW4pR9aMlowqKWm2t3Nh9mkeFxihPSnopOpn053ytlhib9oQyIpYs-ecqNHf2uMlmOYGhbLy7TkVAn5jJg4fhmAcebjAzrelnwq_KqYTe8tcudrD5lIJmvU77areEIn5Q=w1129-h631-no?authuser=0)](https://www.youtube.com/watch?v=DJegKkxdmRs)



### TODO

* Depuración de software y juegos para la mejora continua de la BIOS y el core.
* Eliminación completa de la cache utilizada por el Next186.
* Integración del módulo de video compuesto del proyecto Graphics Gremlin de @schlae.
* Revisar por qué la señal de VGA generada por el módulo de la Graphics Gremlin no funciona en algunos monitores. Ejemplo: FLATRON M1917A
* Mejora y corrección continua de otros fallos.

# Historial de cambios

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
